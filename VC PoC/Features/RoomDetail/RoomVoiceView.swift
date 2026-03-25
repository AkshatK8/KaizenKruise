import SwiftUI

struct RoomVoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppViewModel
    let room: VoiceRoom
    @State private var isLeavingVoice = false
    @State private var leaveFeedbackMessage: String?
    @State private var clearFeedbackTask: Task<Void, Never>?

    private var members: [RoomMember] {
        viewModel.membersByRoom[room.id] ?? []
    }

    private var currentUserID: String? {
        viewModel.currentUser?.id
    }

    private var currentRole: RoomRole? {
        guard let currentUserID else { return nil }
        return members.first(where: { $0.userID == currentUserID })?.role
    }

    private var inCallMembers: [RoomMember] {
        let inCallIDs = viewModel.liveKitService.participantsInCallUserIDs
        guard !inCallIDs.isEmpty else { return [] }

        let byID = Dictionary(uniqueKeysWithValues: members.map { ($0.userID, $0) })
        return inCallIDs.compactMap { byID[$0] }
            .sorted { lhs, rhs in
                if lhs.role == rhs.role {
                    return lhs.displayName < rhs.displayName
                }
                return rolePriority(lhs.role) < rolePriority(rhs.role)
            }
    }

    var body: some View {
        List {
            Section("Room") {
                Text(room.name)
                Text("Invite code: \(room.inviteCode)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                let invite = viewModel.invitePayload(for: room)
                ShareLink(item: invite.deepLink) {
                    Label("Share invite link", systemImage: "square.and.arrow.up")
                }
                Text("Or share code \(invite.code)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("In Call") {
                if inCallMembers.isEmpty {
                    Text(viewModel.liveKitService.isConnected ? "Waiting for participants..." : "Connect audio to see active call participants.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(inCallMembers) { member in
                        participantRow(for: member, showsActions: false)
                    }
                }
            }

            Section("Room Members") {
                ForEach(members) { member in
                    participantRow(for: member, showsActions: true)
                }
            }

            Section("Audio") {
                HStack {
                    Label("Status", systemImage: viewModel.liveKitService.isConnected ? "waveform" : "waveform.slash")
                    Spacer()
                    Text(audioStatusText)
                        .font(.subheadline)
                        .foregroundStyle(audioStatusColor)
                }

                Button(viewModel.liveKitService.isConnected ? "Reconnect Audio" : "Connect Audio") {
                    Task { await viewModel.joinVoice(room: room) }
                }
                .disabled(isLeavingVoice)

                Button(viewModel.liveKitService.isMuted ? "Unmute" : "Mute") {
                    Task { await viewModel.toggleMute() }
                }
                .disabled(!viewModel.liveKitService.isConnected)

                Button("Leave Voice Room", role: .destructive) {
                    Task {
                        isLeavingVoice = true
                        defer { isLeavingVoice = false }
                        await viewModel.leaveVoice()
                        showLeaveFeedback(
                            viewModel.liveKitService.isConnected
                            ? "Could not leave voice room."
                            : "Left voice room."
                        )
                    }
                }
                .disabled(!viewModel.liveKitService.isConnected || isLeavingVoice)

                if isLeavingVoice {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Leaving voice room...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let leaveFeedbackMessage {
                    Text(leaveFeedbackMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if canDeleteRoom {
                Section {
                    Button("Delete Room", role: .destructive) {
                        Task {
                            await viewModel.deleteRoom(roomID: room.id)
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle(room.name)
        .task {
            await viewModel.loadMembers(for: room.id)
        }
        .refreshable {
            await viewModel.loadMembers(for: room.id)
        }
        .onDisappear {
            clearFeedbackTask?.cancel()
        }
    }

    private var canManageMembers: Bool {
        guard let currentRole else { return false }
        return currentRole == .owner || currentRole == .admin
    }

    private var canDeleteRoom: Bool {
        currentRole == .owner
    }

    private func rolePriority(_ role: RoomRole) -> Int {
        switch role {
        case .owner: return 0
        case .admin: return 1
        case .member: return 2
        }
    }

    private func participantRow(for member: RoomMember, showsActions: Bool) -> some View {
        HStack(spacing: 12) {
            AvatarSpeakingView(
                imageURL: member.avatarURL,
                displayName: member.displayName,
                isSpeaking: isSpeaking(member.userID)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                Text(member.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if member.isMuted {
                Image(systemName: "mic.slash.fill")
                    .foregroundStyle(.orange)
            } else if isSpeaking(member.userID) {
                Image(systemName: "waveform")
                    .foregroundStyle(.green)
            }

            if showsActions, canManageMembers, member.userID != currentUserID {
                Button("Remove", role: .destructive) {
                    Task {
                        await viewModel.removeMember(roomID: room.id, targetUserID: member.userID)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func isSpeaking(_ userID: String) -> Bool {
        (viewModel.liveKitService.speakingLevelsByUserID[userID] ?? 0) > 0.02
    }

    private var audioStatusText: String {
        guard viewModel.liveKitService.isConnected else {
            return "Not connected"
        }
        return viewModel.liveKitService.isMuted ? "Connected (Muted)" : "Connected"
    }

    private var audioStatusColor: Color {
        guard viewModel.liveKitService.isConnected else {
            return .secondary
        }
        return viewModel.liveKitService.isMuted ? .orange : .green
    }

    private func showLeaveFeedback(_ message: String) {
        leaveFeedbackMessage = message
        clearFeedbackTask?.cancel()
        clearFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            leaveFeedbackMessage = nil
        }
    }
}

private struct AvatarSpeakingView: View {
    let imageURL: URL?
    let displayName: String
    let isSpeaking: Bool

    var body: some View {
        ZStack {
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.25))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(initials(from: displayName))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
            }
        }
        .overlay {
            Circle()
                .stroke(isSpeaking ? Color.green : Color.clear, lineWidth: 2)
        }
        .shadow(color: isSpeaking ? Color.green.opacity(0.7) : .clear, radius: 10)
        .animation(.easeInOut(duration: 0.15), value: isSpeaking)
    }

    private func initials(from name: String) -> String {
        let pieces = name.split(separator: " ").prefix(2)
        return pieces.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

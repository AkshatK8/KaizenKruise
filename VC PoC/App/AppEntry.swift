import Combine
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var rooms: [VoiceRoom] = []
    @Published var selectedRoom: VoiceRoom?
    @Published var membersByRoom: [String: [RoomMember]] = [:]
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var isConfigured = true

    private let supabaseClient = SupabaseClientService()
    let liveKitService = LiveKitService()
    let permissionService = PermissionService()
    let roomService: RoomService

    init() {
        self.roomService = RoomService(authClient: supabaseClient)
        self.isConfigured = AppConfig.isConfiguredForRemoteServices
    }

    func signIn(email: String, password: String) async {
        await runTask {
            self.currentUser = try await self.supabaseClient.signIn(email: email, password: password)
            try await self.reloadRooms()
        }
    }

    func signUp(email: String, password: String) async {
        await runTask {
            try await self.supabaseClient.signUp(email: email, password: password)
            self.errorMessage = "Account created. Please sign in."
        }
    }

    func restoreSessionIfAvailable() async {
        guard isConfigured else { return }
        await runTask {
            self.currentUser = try await self.supabaseClient.restoreSession()
            try await self.reloadRooms()
        }
    }

    func signOut() async {
        await supabaseClient.signOut()
        currentUser = nil
        rooms = []
        selectedRoom = nil
        await liveKitService.disconnect()
    }

    func reloadRooms() async throws {
        guard let user = currentUser else {
            rooms = []
            return
        }
        rooms = try await roomService.fetchRooms(for: user)
    }

    func createRoom(name: String) async -> Bool {
        await runTask {
            guard let user = self.currentUser else { return }
            let room = try await self.roomService.createRoom(name: name, creator: user)
            try await self.reloadRooms()
            self.selectedRoom = room
        }
    }

    func joinRoom(code: String) async -> Bool {
        await runTask {
            guard let user = self.currentUser else { return }
            let room = try await self.roomService.joinRoom(code: code, user: user)
            try await self.reloadRooms()
            self.selectedRoom = room
        }
    }

    func loadMembers(for roomID: String) async {
        await runTask {
            let members = try await self.roomService.listMembers(roomID: roomID)
            self.membersByRoom[roomID] = members
        }
    }

    func removeMember(roomID: String, targetUserID: String) async {
        await runTask {
            guard let user = self.currentUser else { return }
            try await self.roomService.removeMember(roomID: roomID, actor: user, targetUserID: targetUserID)
            let members = try await self.roomService.listMembers(roomID: roomID)
            self.membersByRoom[roomID] = members
        }
    }

    func deleteRoom(roomID: String) async {
        await runTask {
            guard let user = self.currentUser else { return }
            try await self.roomService.deleteRoom(roomID: roomID, actor: user)
            await self.liveKitService.disconnect()
            try await self.reloadRooms()
        }
    }

    func joinVoice(room: VoiceRoom) async {
        await runTask {
            guard let user = self.currentUser else { return }
            let hasMicrophone = await self.permissionService.requestMicrophonePermissionIfNeeded()
            guard hasMicrophone else {
                throw AppError.message("Microphone permission is required to join voice.")
            }
            let payload = try await self.roomService.liveKitPayload(for: room, user: user)
            try await self.liveKitService.connect(to: payload)
        }
    }

    func leaveVoice() async {
        await liveKitService.disconnect()
    }

    func toggleMute() async {
        await runTask {
            try await self.liveKitService.setMuted(!self.liveKitService.isMuted)
        }
    }

    func invitePayload(for room: VoiceRoom) -> InvitePayload {
        roomService.invitePayload(for: room)
    }

    @discardableResult
    private func runTask(_ work: @escaping () async throws -> Void) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            try await work()
            return true
        } catch {
            MonitoringService.shared.capture(error: error, context: "AppViewModel")
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct AppEntry: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        Group {
            if !viewModel.isConfigured {
                SetupRequiredView()
            } else if viewModel.currentUser == nil {
                AuthView(viewModel: viewModel)
            } else {
                RoomsListView(viewModel: viewModel)
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unexpected error.")
        }
        .task {
            await viewModel.restoreSessionIfAvailable()
        }
    }
}

private struct SetupRequiredView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Configuration required") {
                    Text("Set these environment variables in your Xcode run scheme:")
                    Text("SUPABASE_URL")
                    Text("SUPABASE_ANON_KEY")
                    Text("LIVEKIT_URL")
                    Text("LIVEKIT_TOKEN_FUNCTION_URL")
                }
            }
            .navigationTitle("Setup Required")
        }
    }
}

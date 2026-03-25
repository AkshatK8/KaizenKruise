import AVFoundation
import Combine
import Foundation

#if canImport(LiveKit)
import LiveKit
#endif

@MainActor
final class LiveKitService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isMuted = false
    @Published private(set) var participantsInCallUserIDs: Set<String> = []
    @Published private(set) var speakingLevelsByUserID: [String: Float] = [:]

    #if canImport(LiveKit)
    private var room: LiveKit.Room?
    #endif

    func connect(to payload: LiveKitJoinPayload) async throws {
        try configureAudioSession()

        #if canImport(LiveKit)
        let room = LiveKit.Room()
        room.delegates.add(delegate: self)
        try await room.connect(url: payload.url.absoluteString, token: payload.token)
        self.room = room
        refreshParticipantState(from: room)
        #endif

        isConnected = true
        isMuted = false
    }

    func disconnect() async {
        #if canImport(LiveKit)
        await room?.disconnect()
        room = nil
        #endif
        isConnected = false
        participantsInCallUserIDs = []
        speakingLevelsByUserID = [:]
    }

    func setMuted(_ muted: Bool) async throws {
        #if canImport(LiveKit)
        _ = try await room?.localParticipant.setMicrophone(enabled: !muted)
        #endif
        isMuted = muted
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.allowBluetoothHFP, .defaultToSpeaker])
        try session.setMode(.voiceChat)
        try session.setActive(true)
    }

    private func refreshParticipantState(from room: LiveKit.Room) {
        var nextParticipants = Set<String>()
        var nextSpeakingLevels: [String: Float] = [:]

        if let localIdentity = room.localParticipant.identity?.stringValue {
            nextParticipants.insert(localIdentity)
            let level = room.localParticipant.isSpeaking ? room.localParticipant.audioLevel : 0
            nextSpeakingLevels[localIdentity] = max(level, 0)
        }

        for participant in room.remoteParticipants.values {
            guard let identity = participant.identity?.stringValue else { continue }
            nextParticipants.insert(identity)
            let level = participant.isSpeaking ? participant.audioLevel : 0
            nextSpeakingLevels[identity] = max(level, 0)
        }

        participantsInCallUserIDs = nextParticipants
        speakingLevelsByUserID = nextSpeakingLevels
    }
}

#if canImport(LiveKit)
extension LiveKitService: RoomDelegate {
    nonisolated func room(_ room: LiveKit.Room, participantDidConnect participant: LiveKit.RemoteParticipant) {
        _ = participant
        Task { @MainActor in
            self.refreshParticipantState(from: room)
        }
    }

    nonisolated func room(_ room: LiveKit.Room, participantDidDisconnect participant: LiveKit.RemoteParticipant) {
        _ = participant
        Task { @MainActor in
            self.refreshParticipantState(from: room)
        }
    }

    nonisolated func room(_ room: LiveKit.Room, didUpdateSpeakingParticipants participants: [LiveKit.Participant]) {
        _ = participants
        Task { @MainActor in
            self.refreshParticipantState(from: room)
        }
    }

    nonisolated func room(_ room: LiveKit.Room, participant: LiveKit.Participant, trackPublication: LiveKit.TrackPublication, didUpdateIsMuted isMuted: Bool) {
        _ = (participant, trackPublication, isMuted)
        Task { @MainActor in
            self.refreshParticipantState(from: room)
        }
    }
}
#endif

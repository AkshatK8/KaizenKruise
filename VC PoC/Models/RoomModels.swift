import Foundation

struct AppUser: Identifiable, Hashable {
    let id: String
    let email: String
    var displayName: String
}

struct VoiceRoom: Identifiable, Hashable {
    let id: String
    var name: String
    var ownerID: String
    var inviteCode: String
    var createdAt: Date
}

enum RoomRole: String, Codable, CaseIterable {
    case owner
    case admin
    case member
}

struct RoomMember: Identifiable, Hashable {
    var id: String { userID }
    let userID: String
    let displayName: String
    let avatarURL: URL?
    let role: RoomRole
    var isMuted: Bool
}

struct InvitePayload {
    let code: String
    let deepLink: URL
}

struct LiveKitJoinPayload {
    let token: String
    let roomName: String
    let url: URL
}

enum AppError: LocalizedError {
    case configurationMissing
    case packageMissing
    case unauthenticated
    case message(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "Missing required app configuration."
        case .packageMissing:
            return "Required Swift packages are missing from the project."
        case .unauthenticated:
            return "Please sign in to continue."
        case let .message(message):
            return message
        }
    }
}

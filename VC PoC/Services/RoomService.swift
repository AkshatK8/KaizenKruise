import Foundation
#if canImport(Supabase)
import Supabase
#endif

@MainActor
final class RoomService {
    private let authClient: SupabaseClientService

    init(authClient: SupabaseClientService) {
        self.authClient = authClient
    }

    private struct RoomRow: Decodable {
        let id: UUID
        let name: String
        let owner_id: UUID
        let invite_code: String
        let created_at: Date
    }

    private struct MemberProfileRow: Decodable {
        let display_name: String
        let avatar_url: String?
    }

    private struct MemberRow: Decodable {
        let user_id: UUID
        let role: RoomRole
        let profiles: MemberProfileRow?
    }

    private struct TokenFunctionResponse: Decodable {
        let token: String
        let livekitUrl: String
        let roomName: String
    }

    private struct TokenFunctionErrorResponse: Decodable {
        let error: String?
        let details: String?
    }

    func fetchRooms(for user: AppUser) async throws -> [VoiceRoom] {
        #if canImport(Supabase)
        let client = try authClient.supabase()
        let rows: [RoomRow] = try await client
            .from("rooms")
            .select("id,name,owner_id,invite_code,created_at")
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map(mapRoomRow)
        #else
        _ = user
        throw AppError.packageMissing
        #endif
    }

    func createRoom(name: String, creator: AppUser) async throws -> VoiceRoom {
        #if canImport(Supabase)
        let client = try authClient.supabase()
        let row: RoomRow = try await client
            .rpc("create_room", params: ["input_name": name])
            .execute()
            .value
        return mapRoomRow(row)
        #else
        _ = (name, creator)
        throw AppError.packageMissing
        #endif
    }

    func joinRoom(code: String, user: AppUser) async throws -> VoiceRoom {
        #if canImport(Supabase)
        let normalized = code.filter(\.isNumber)
        guard normalized.count == 4 else {
            throw AppError.message("Code must be 4 digits.")
        }
        let client = try authClient.supabase()
        let row: RoomRow = try await client
            .rpc("join_room_by_code", params: ["input_code": normalized])
            .execute()
            .value
        return mapRoomRow(row)
        #else
        _ = (code, user)
        throw AppError.packageMissing
        #endif
    }

    func listMembers(roomID: String) async throws -> [RoomMember] {
        #if canImport(Supabase)
        let client = try authClient.supabase()
        let rows: [MemberRow] = try await client
            .from("room_members")
            .select("user_id,role,profiles(display_name,avatar_url)")
            .eq("room_id", value: roomID)
            .execute()
            .value
        return rows.map { row in
            RoomMember(
                userID: row.user_id.uuidString,
                displayName: row.profiles?.display_name ?? "Member",
                avatarURL: row.profiles?.avatar_url.flatMap(URL.init(string:)),
                role: row.role,
                isMuted: false
            )
        }.sorted(by: { lhs, rhs in
            if lhs.role == rhs.role {
                return lhs.displayName < rhs.displayName
            }
            return rolePriority(lhs.role) < rolePriority(rhs.role)
        })
        #else
        _ = roomID
        throw AppError.packageMissing
        #endif
    }

    func removeMember(roomID: String, actor: AppUser, targetUserID: String) async throws {
        #if canImport(Supabase)
        let client = try authClient.supabase()
        _ = try await client.rpc(
            "remove_room_member",
            params: [
                "input_room_id": roomID,
                "input_user_id": targetUserID
            ]
        ).execute()
        #else
        _ = (roomID, actor, targetUserID)
        throw AppError.packageMissing
        #endif
    }

    func deleteRoom(roomID: String, actor: AppUser) async throws {
        #if canImport(Supabase)
        let client = try authClient.supabase()
        _ = try await client.rpc(
            "delete_room",
            params: ["input_room_id": roomID]
        ).execute()
        #else
        _ = (roomID, actor)
        throw AppError.packageMissing
        #endif
    }

    func invitePayload(for room: VoiceRoom) -> InvitePayload {
        let url = URL(string: "vcpoc://join?code=\(room.inviteCode)")!
        return InvitePayload(code: room.inviteCode, deepLink: url)
    }

    func liveKitPayload(for room: VoiceRoom, user: AppUser) async throws -> LiveKitJoinPayload {
        guard let tokenURL = AppConfig.liveKitTokenFunctionURL else {
            throw AppError.configurationMissing
        }

        let accessToken = try await authClient.accessToken()
        let authHeader = accessToken.lowercased().hasPrefix("bearer ")
            ? accessToken
            : "Bearer \(accessToken)"
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        if let anonKey = AppConfig.supabaseAnonKey, !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.httpBody = try JSONEncoder().encode(["roomId": room.id])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.message("Failed to fetch LiveKit token: invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let backendMessage = (try? JSONDecoder().decode(TokenFunctionErrorResponse.self, from: data))
                .map { [$0.error, $0.details].compactMap { $0 }.joined(separator: " - ") }
                .flatMap { $0.isEmpty ? nil : $0 }
            let fallbackMessage = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let details = backendMessage ?? (fallbackMessage?.isEmpty == false ? fallbackMessage : nil) ?? "Unknown server error"
            throw AppError.message("Failed to fetch LiveKit token (\(httpResponse.statusCode)): \(details)")
        }

        let payload = try JSONDecoder().decode(TokenFunctionResponse.self, from: data)
        guard let roomURL = URL(string: payload.livekitUrl) else {
            throw AppError.message("Invalid LiveKit URL returned from token endpoint.")
        }

        return LiveKitJoinPayload(
            token: payload.token,
            roomName: payload.roomName,
            url: roomURL
        )
    }

    private func rolePriority(_ role: RoomRole) -> Int {
        switch role {
        case .owner: return 0
        case .admin: return 1
        case .member: return 2
        }
    }

    private func mapRoomRow(_ row: RoomRow) -> VoiceRoom {
        VoiceRoom(
            id: row.id.uuidString,
            name: row.name,
            ownerID: row.owner_id.uuidString,
            inviteCode: row.invite_code,
            createdAt: row.created_at
        )
    }
}

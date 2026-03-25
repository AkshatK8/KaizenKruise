import Foundation

#if canImport(Supabase)
import Supabase
#endif

@MainActor
final class SupabaseClientService {
    private(set) var signedInUser: AppUser?

    #if canImport(Supabase)
    private let client: SupabaseClient?
    #endif

    init() {
        #if canImport(Supabase)
        if let url = AppConfig.supabaseURL, let key = AppConfig.supabaseAnonKey {
            self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        } else {
            self.client = nil
        }
        #endif
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        #if canImport(Supabase)
        guard let client else {
            throw AppError.configurationMissing
        }

        _ = try await client.auth.signIn(
            email: email,
            password: password
        )
        let user = try await authUserFromSession(client: client)
        signedInUser = user
        return user
        #else
        throw AppError.packageMissing
        #endif
    }

    func signUp(email: String, password: String) async throws {
        #if canImport(Supabase)
        guard let client else {
            throw AppError.configurationMissing
        }

        _ = try await client.auth.signUp(
            email: email,
            password: password
        )
        #else
        throw AppError.packageMissing
        #endif
    }

    func restoreSession() async throws -> AppUser? {
        #if canImport(Supabase)
        guard let client else {
            throw AppError.configurationMissing
        }
        let session = try await client.auth.session
        guard !session.accessToken.isEmpty else {
            signedInUser = nil
            return nil
        }
        let user = try await authUserFromSession(client: client)
        signedInUser = user
        return user
        #else
        throw AppError.packageMissing
        #endif
    }

    func accessToken() async throws -> String {
        #if canImport(Supabase)
        guard let client else {
            throw AppError.configurationMissing
        }
        let session = try await client.auth.session
        return session.accessToken
        #else
        throw AppError.packageMissing
        #endif
    }

    #if canImport(Supabase)
    func supabase() throws -> SupabaseClient {
        guard let client else {
            throw AppError.configurationMissing
        }
        return client
    }

    private func authUserFromSession(client: SupabaseClient) async throws -> AppUser {
        let authUser = try await client.auth.user()
        let email = authUser.email ?? "unknown@email.com"
        let user = AppUser(
            id: authUser.id.uuidString,
            email: email,
            displayName: email.components(separatedBy: "@").first ?? "User"
        )
        return user
    }
    #endif

    func signOut() async {
        #if canImport(Supabase)
        if let client {
            try? await client.auth.signOut()
        }
        #endif
        signedInUser = nil
    }
}

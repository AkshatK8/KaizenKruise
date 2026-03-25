import Foundation

enum AppConfig {
    static var supabaseURL: URL? {
        guard let raw = ProcessInfo.processInfo.environment["SUPABASE_URL"] else {
            return nil
        }
        return URL(string: raw)
    }

    static var supabaseAnonKey: String? {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
    }

    static var liveKitURL: URL? {
        guard let raw = ProcessInfo.processInfo.environment["LIVEKIT_URL"] else {
            return nil
        }
        return URL(string: raw)
    }

    static var liveKitTokenFunctionURL: URL? {
        guard let raw = ProcessInfo.processInfo.environment["LIVEKIT_TOKEN_FUNCTION_URL"] else {
            return nil
        }
        return URL(string: raw)
    }

    static var isConfiguredForRemoteServices: Bool {
        supabaseURL != nil &&
        !(supabaseAnonKey ?? "").isEmpty &&
        liveKitURL != nil &&
        liveKitTokenFunctionURL != nil
    }
}

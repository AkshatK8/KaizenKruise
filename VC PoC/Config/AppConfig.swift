import Foundation

enum AppConfig {
    // Scheme env vars are only available when launched from Xcode.
    // TestFlight/App Store builds need bundled defaults.
    private enum BundledDefaults {
        static let supabaseURL = "https://creqeakdkiusbgmyyvtd.supabase.co"
        static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNyZXFlYWtka2l1c2JnbXl5dnRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjMzODgsImV4cCI6MjA5MDAzOTM4OH0.F9WngUAuorwfRb6jBu1cs1R5pApnUSZBNygl-J_Wvj0"
        static let liveKitURL = "wss://vc-poc-vr2xb67w.livekit.cloud"
        static let liveKitTokenFunctionURL = "https://creqeakdkiusbgmyyvtd.supabase.co/functions/v1/livekit-token"
    }

    private static func configValue(_ key: String, fallback: String? = nil) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envValue.isEmpty {
            return envValue
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        if let fallback {
            let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    static var supabaseURL: URL? {
        guard let raw = configValue("SUPABASE_URL", fallback: BundledDefaults.supabaseURL) else {
            return nil
        }
        return URL(string: raw)
    }

    static var supabaseAnonKey: String? {
        configValue("SUPABASE_ANON_KEY", fallback: BundledDefaults.supabaseAnonKey)
    }

    static var liveKitURL: URL? {
        guard let raw = configValue("LIVEKIT_URL", fallback: BundledDefaults.liveKitURL) else {
            return nil
        }
        return URL(string: raw)
    }

    static var liveKitTokenFunctionURL: URL? {
        guard let raw = configValue("LIVEKIT_TOKEN_FUNCTION_URL", fallback: BundledDefaults.liveKitTokenFunctionURL) else {
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

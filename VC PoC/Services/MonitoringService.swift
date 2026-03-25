import Foundation

@MainActor
final class MonitoringService {
    static let shared = MonitoringService()

    private init() {}

    func capture(error: Error, context: String) {
        // Replace with Sentry SDK capture when connected.
        print("Monitoring[\(context)]: \(error.localizedDescription)")
    }
}

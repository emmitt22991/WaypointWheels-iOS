import Foundation

/// Application-wide notification constants.
extension Notification.Name {
    /// Posted when the user's authentication session becomes invalid and a fresh sign-in is required.
    static let sessionExpired = Notification.Name("com.stepstonetexas.waypointwheels.sessionExpired")
}

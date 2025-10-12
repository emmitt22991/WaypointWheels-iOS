import Foundation

extension Error {
    /// Returns a user-friendly description of the error that is safe to show in the UI.
    var userFacingMessage: String {
        localizedDescription.sanitizedForDisplay()
    }
}

private extension String {
    func sanitizedForDisplay() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let lowercasedValue = trimmed.lowercased()
        let htmlIndicators = ["<!doctype", "<html", "<body", "</html>"]

        if htmlIndicators.contains(where: { lowercasedValue.contains($0) }) {
            return "Something went wrong while communicating with the server. Please try again."
        }

        return trimmed
    }
}

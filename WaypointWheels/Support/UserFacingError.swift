import Foundation

extension Error {
    var userFacingMessage: String {
        // Check for TripsService.TripsError first
        if let tripsError = self as? TripsService.TripsError {
            return tripsError.userFacingMessage
        }
        
        // Check for LocalizedError
        if let localizedError = self as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        
        // Fallback to generic message
        return "An unexpected error occurred."
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



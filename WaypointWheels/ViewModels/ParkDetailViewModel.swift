import Foundation

@MainActor
final class ParkDetailViewModel: ObservableObject {
    @Published private(set) var summary: Park
    @Published private(set) var detail: ParkDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var userRating: Double?
    @Published var ratingDraft: Double
    @Published var reviewRatingDraft: Double
    @Published var reviewDraft: String = ""
    @Published var photoCaption: String = ""
    @Published private(set) var isSubmittingRating = false
    @Published private(set) var isSubmittingReview = false
    @Published private(set) var isUploadingPhoto = false
    @Published var alertMessage: String?

    private var hasLoaded = false
    private let parkID: UUID
    private let service: ParksService
    private let onParkUpdated: (Park) -> Void

    init(parkID: UUID,
         initialSummary: Park,
         service: ParksService = ParksService(),
         onParkUpdated: @escaping (Park) -> Void,
         prefetchedDetail: ParkDetail? = nil) {
        self.parkID = parkID
        self.summary = initialSummary
        self.service = service
        self.onParkUpdated = onParkUpdated
        self.detail = prefetchedDetail
        if let prefetchedDetail {
            self.userRating = prefetchedDetail.userRating
            let value = prefetchedDetail.userRating ?? prefetchedDetail.summary.rating
            self.ratingDraft = value
            self.reviewRatingDraft = value
            self.hasLoaded = true
        } else {
            self.ratingDraft = initialSummary.rating
            self.reviewRatingDraft = initialSummary.rating
        }
    }

    func loadParkIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            let detail = try await service.fetchParkDetail(parkID: parkID)
            apply(detail: detail)
            hasLoaded = true
        } catch {
            errorMessage = error.userFacingMessage
        }
        isLoading = false
    }

    func submitRating() async {
        guard !isSubmittingRating else { return }
        guard ratingDraft > 0 else {
            alertMessage = "Choose a rating above zero before submitting."
            return
        }

        isSubmittingRating = true
        do {
            let updatedPark = try await service.submitRating(parkID: parkID, rating: ratingDraft)
            summary = updatedPark
            userRating = ratingDraft
            onParkUpdated(updatedPark)
            await reload()
        } catch {
            alertMessage = error.userFacingMessage
        }
        isSubmittingRating = false
    }

    func submitReview() async {
        guard !isSubmittingReview else { return }
        let trimmedComment = reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            alertMessage = "Please enter a review before submitting."
            return
        }

        isSubmittingReview = true
        do {
            _ = try await service.submitReview(parkID: parkID, rating: reviewRatingDraft, comment: trimmedComment)
            reviewDraft = ""
            await reload()
        } catch {
            alertMessage = error.userFacingMessage
        }
        isSubmittingReview = false
    }

    func uploadPhoto(data: Data, filename: String) async {
        guard !isUploadingPhoto else { return }
        guard !data.isEmpty else {
            alertMessage = "Select a photo before uploading."
            return
        }

        isUploadingPhoto = true
        do {
            _ = try await service.uploadPhoto(parkID: parkID, data: data, filename: filename, caption: photoCaption.isEmpty ? nil : photoCaption)
            photoCaption = ""
            await reload()
        } catch {
            alertMessage = error.userFacingMessage
        }
        isUploadingPhoto = false
    }

    private func apply(detail: ParkDetail) {
        self.detail = detail
        self.summary = detail.summary
        self.userRating = detail.userRating
        let userValue = detail.userRating ?? detail.summary.rating
        ratingDraft = userValue
        reviewRatingDraft = userValue
        onParkUpdated(detail.summary)
    }
}

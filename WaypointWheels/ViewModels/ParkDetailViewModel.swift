import Foundation

@MainActor
final class ParkDetailViewModel: ObservableObject {
    @Published private(set) var summary: Park
    @Published private(set) var detail: ParkDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var userRating: Double?
    @Published var ratingDraft: Double
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
            self.hasLoaded = true
        } else {
            self.ratingDraft = initialSummary.rating
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
            userRating = ratingDraft

            if detail != nil {
                applyLocalDetailUpdate { detail in
                    ParkDetail(
                        summary: updatedPark,
                        familyPhotos: detail.familyPhotos,
                        communityPhotos: detail.communityPhotos,
                        amenities: detail.amenities,
                        notes: detail.notes,
                        familyReviews: detail.familyReviews,
                        communityReviews: detail.communityReviews,
                        userRating: ratingDraft,
                        userReview: detail.userReview
                    )
                }
            } else {
                summary = updatedPark
                onParkUpdated(updatedPark)
            }

            await reload()
        } catch {
            alertMessage = error.userFacingMessage
        }
        isSubmittingRating = false
    }

    func submitReview() async {
        guard !isSubmittingReview else { return }
        guard ratingDraft > 0 else {
            alertMessage = "Choose a rating above zero before submitting."
            return
        }
        let trimmedComment = reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            alertMessage = "Please enter a review before submitting."
            return
        }

        isSubmittingReview = true
        do {
            let review = try await service.submitReview(parkID: parkID, rating: ratingDraft, comment: trimmedComment)
            reviewDraft = ""
            userRating = ratingDraft

            applyLocalDetailUpdate { detail in
                var familyReviews = detail.familyReviews
                var communityReviews = detail.communityReviews

                if review.isFamilyReview {
                    familyReviews.insert(review, at: 0)
                } else {
                    communityReviews.insert(review, at: 0)
                }

                let updatedSummary = summary(afterAdding: review, to: detail)

                return ParkDetail(
                    summary: updatedSummary,
                    familyPhotos: detail.familyPhotos,
                    communityPhotos: detail.communityPhotos,
                    amenities: detail.amenities,
                    notes: detail.notes,
                    familyReviews: familyReviews,
                    communityReviews: communityReviews,
                    userRating: ratingDraft,
                    userReview: review
                )
            }

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
            let photo = try await service.uploadPhoto(parkID: parkID, data: data, filename: filename, caption: photoCaption.isEmpty ? nil : photoCaption)
            photoCaption = ""

            applyLocalDetailUpdate { detail in
                var familyPhotos = detail.familyPhotos
                var communityPhotos = detail.communityPhotos

                if photo.isFamilyPhoto {
                    familyPhotos.insert(photo, at: 0)
                } else {
                    communityPhotos.insert(photo, at: 0)
                }

                return ParkDetail(
                    summary: detail.summary,
                    familyPhotos: familyPhotos,
                    communityPhotos: communityPhotos,
                    amenities: detail.amenities,
                    notes: detail.notes,
                    familyReviews: detail.familyReviews,
                    communityReviews: detail.communityReviews,
                    userRating: detail.userRating,
                    userReview: detail.userReview
                )
            }

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
        onParkUpdated(detail.summary)
    }

    private func applyLocalDetailUpdate(_ transform: (ParkDetail) -> ParkDetail) {
        guard let currentDetail = detail else { return }
        let newDetail = transform(currentDetail)
        detail = newDetail
        summary = newDetail.summary
        onParkUpdated(newDetail.summary)
    }

    private func summary(afterAdding review: ParkDetail.Review, to detail: ParkDetail) -> Park {
        let base = detail.summary

        if review.isFamilyReview {
            let existingTotal = base.familyRating * Double(base.familyReviewCount)
            let newCount = base.familyReviewCount + 1
            let newAverage = (existingTotal + review.rating) / Double(newCount)
            return base.updating(
                familyRating: newAverage,
                familyReviewCount: newCount
            )
        } else {
            let existingTotal = (base.communityRating ?? 0) * Double(base.communityReviewCount)
            let newCount = base.communityReviewCount + 1
            let newAverage = (existingTotal + review.rating) / Double(newCount)
            return base.updating(
                communityRating: .some(newAverage),
                communityReviewCount: newCount
            )
        }
    }
}

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct ParkDetailView: View {
    @StateObject private var viewModel: ParkDetailViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoPreview: Image?
    @FocusState private var isReviewFocused: Bool

    init(viewModel: ParkDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            summarySection

            if viewModel.isLoading && viewModel.detail == nil {
                loadingSection
            }

            if let errorMessage = viewModel.errorMessage, viewModel.detail == nil {
                errorSection(errorMessage)
            }

            if let detail = viewModel.detail {
                if !detail.orderedPhotos.isEmpty {
                    photosSection(detail)
                }

                if !detail.amenities.isEmpty {
                    amenitiesSection(detail)
                }

                if !detail.notes.isEmpty {
                    notesSection(detail)
                }

                commentsSection(detail)
                ratingFormSection
                reviewFormSection
                photoUploadSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(backgroundGradient)
        .navigationTitle(viewModel.summary.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadParkIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { viewModel.alertMessage != nil },
                                    set: { if !$0 { viewModel.alertMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            loadPreview(for: newValue)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(colors: [
            Color(red: 0.97, green: 0.94, blue: 0.86),
            Color(red: 0.92, green: 0.97, blue: 0.98)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.summary.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(viewModel.summary.formattedLocation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ratingBadge
                }

                memberships
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private var ratingBadge: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Family rating")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                        Text(String(format: "%.1f", viewModel.summary.familyRating))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.98, green: 0.88, blue: 0.63), in: Capsule())
                    .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
                }

                if let community = viewModel.summary.communityRating {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Community")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "person.3.fill")
                            Text(String(format: "%.1f", community))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.94, green: 0.90, blue: 0.99), in: Capsule())
                        .foregroundStyle(Color(red: 0.42, green: 0.37, blue: 0.67))
                    }
                }
            }

            if let summaryText = ratingSummaryText {
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let userRating = viewModel.userRating {
                Text("Your rating: \(String(format: "%.1f", userRating))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ratingSummaryText: String? {
        let familyCount = viewModel.summary.familyReviewCount
        let communityCount = viewModel.summary.communityReviewCount

        switch (familyCount, communityCount) {
        case (0, 0):
            return nil
        case (_, 0):
            return "\(familyCount) family comments"
        case (0, _):
            return "\(communityCount) community comments"
        default:
            return "\(familyCount) family · \(communityCount) community comments"
        }
    }

    private var memberships: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.summary.memberships, id: \.id) { membership in
                Text(membership.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(membership.badgeColor.opacity(0.18), in: Capsule())
                    .foregroundStyle(membership.badgeColor)
            }
        }
    }

    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView("Loading park…")
                    .progressViewStyle(.circular)
                Spacer()
            }
            .padding(.vertical, 16)
        }
        .listRowBackground(Color.clear)
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .listRowBackground(Color.clear)
    }

    private func photosSection(_ detail: ParkDetail) -> some View {
        Section("Gallery") {
            VStack(alignment: .leading, spacing: 20) {
                if !detail.familyPhotos.isEmpty {
                    photoCarousel(title: "Your crew", icon: "person.2.fill", photos: detail.familyPhotos, highlightColor: Color(red: 0.36, green: 0.31, blue: 0.55))
                }

                if !detail.communityPhotos.isEmpty {
                    photoCarousel(title: "Community", icon: "person.3", photos: detail.communityPhotos, highlightColor: Color(red: 0.42, green: 0.37, blue: 0.67).opacity(0.85))
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private func photoCarousel(title: String, icon: String, photos: [ParkDetail.Photo], highlightColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(highlightColor)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(photos) { photo in
                        photoCard(for: photo, accent: highlightColor)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }

    private func photoCard(for photo: ParkDetail.Photo, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: photo.imageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray5))
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 220, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topLeading) {
                if photo.isFamilyPhoto {
                    Text("Your family")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(accent.opacity(0.9), in: Capsule())
                        .foregroundStyle(Color.white)
                        .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let uploader = photo.uploadedBy, !uploader.isEmpty {
                    Text(uploader)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
            }

            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 220, alignment: .leading)
    }

    private func amenitiesSection(_ detail: ParkDetail) -> some View {
        Section("Amenities") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(detail.amenities) { amenity in
                    VStack(spacing: 8) {
                        Image(systemName: amenity.systemImage)
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                        Text(amenity.name)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private func notesSection(_ detail: ParkDetail) -> some View {
        Section("Family Notes") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(detail.notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private func commentsSection(_ detail: ParkDetail) -> some View {
        Section("Comments & Reviews") {
            if detail.familyReviews.isEmpty && detail.communityReviews.isEmpty {
                Text("No comments yet. Be the first to share your stay!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    if !detail.familyReviews.isEmpty {
                        reviewGroup(title: "Your family", icon: "heart.circle.fill", accent: Color(red: 0.36, green: 0.31, blue: 0.55), reviews: detail.familyReviews)
                    }

                    if !detail.communityReviews.isEmpty {
                        reviewGroup(title: "Community", icon: "person.3", accent: Color(red: 0.42, green: 0.37, blue: 0.67), reviews: detail.communityReviews)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listRowBackground(Color.clear)
    }

    private func reviewGroup(title: String, icon: String, accent: Color, reviews: [ParkDetail.Review]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(reviews) { review in
                    reviewCard(review, accent: accent)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    private func reviewCard(_ review: ParkDetail.Review, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                    Text(String(format: "%.1f", review.rating))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent.opacity(0.15), in: Capsule())
                .foregroundStyle(accent)

                Spacer()

                Text(review.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(review.comment)
                .font(.body)

            HStack {
                Text("— \(review.authorName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if review.isFamilyReview {
                    Label("Family", systemImage: "heart.fill")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var ratingFormSection: some View {
        Section("Rate this park") {
            VStack(alignment: .leading, spacing: 12) {
                Slider(value: $viewModel.ratingDraft, in: 0...5, step: 0.5) {
                    Text("Rating")
                } minimumValueLabel: {
                    Text("0")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("5")
                        .font(.caption)
                }

                Text("Selected: \(String(format: "%.1f", viewModel.ratingDraft))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await viewModel.submitRating() }
                } label: {
                    if viewModel.isSubmittingRating {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Submit Rating", systemImage: "star.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmittingRating)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private var reviewFormSection: some View {
        Section("Leave a review") {
            VStack(alignment: .leading, spacing: 12) {
                Slider(value: $viewModel.reviewRatingDraft, in: 0...5, step: 0.5) {
                    Text("Review rating")
                } minimumValueLabel: {
                    Text("0")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("5")
                        .font(.caption)
                }

                TextEditor(text: $viewModel.reviewDraft)
                    .focused($isReviewFocused)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(.systemGray4)))

                Button {
                    Task {
                        await viewModel.submitReview()
                        if viewModel.alertMessage == nil {
                            isReviewFocused = false
                        }
                    }
                } label: {
                    if viewModel.isSubmittingReview {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Post Review", systemImage: "text.bubble")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSubmittingReview)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private var photoUploadSection: some View {
        Section("Share a photo") {
            VStack(alignment: .leading, spacing: 12) {
                let previewLabel = makePhotoPickerLabel()
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    previewLabel
                }

                TextField("Caption (optional)", text: $viewModel.photoCaption)
                    .textFieldStyle(.roundedBorder)

                Button {
                    guard let data = selectedPhotoData else {
                        viewModel.alertMessage = "Select a photo before uploading."
                        return
                    }
                    Task {
                        await viewModel.uploadPhoto(data: data, filename: selectedPhotoItem?.itemIdentifier ?? "upload.jpg")
                        if viewModel.alertMessage == nil {
                            selectedPhotoItem = nil
                            selectedPhotoData = nil
                            selectedPhotoPreview = nil
                        }
                    }
                } label: {
                    if viewModel.isUploadingPhoto {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Upload Photo", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isUploadingPhoto)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private func makePhotoPickerLabel() -> some View {
        Group {
            if let preview = selectedPhotoPreview {
                preview
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                            .padding(8)
                    }
            } else {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose Photo")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.systemGray4)))
            }
        }
    }

    @MainActor
    private var photoPickerLabel: some View {
        Group {
            if let preview = selectedPhotoPreview {
                preview
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                            .padding(8)
                    }
            } else {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose Photo")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.systemGray4)))
            }
        }
    }

    private func loadPreview(for item: PhotosPickerItem?) {
        guard let item else {
            selectedPhotoData = nil
            selectedPhotoPreview = nil
            return
        }

        Task.detached {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        self.selectedPhotoData = data
#if canImport(UIKit)
                        if let uiImage = UIImage(data: data) {
                            self.selectedPhotoPreview = Image(uiImage: uiImage)
                        } else {
                            self.selectedPhotoPreview = nil
                        }
#else
                        self.selectedPhotoPreview = nil
#endif
                    }
                }
            } catch {
                await MainActor.run {
                    self.viewModel.alertMessage = error.userFacingMessage
                }
            }
        }
    }
}



#Preview {
    let park = Park.sampleData[0]
    let detail = ParkDetail(
        summary: park,
        familyPhotos: [],
        communityPhotos: [],
        amenities: park.amenities,
        notes: park.featuredNotes,
        familyReviews: [],
        communityReviews: [],
        userRating: 4.5,
        userReview: nil
    )
    let viewModel = ParkDetailViewModel(parkID: park.id,
                                        initialSummary: park,
                                        onParkUpdated: { _ in },
                                        prefetchedDetail: detail)
    return NavigationStack {
        ParkDetailView(viewModel: viewModel)
    }
}

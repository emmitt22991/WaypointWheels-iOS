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
                if !detail.photos.isEmpty {
                    photosSection(detail)
                }

                if !detail.amenities.isEmpty {
                    amenitiesSection(detail)
                }

                if !detail.notes.isEmpty {
                    notesSection(detail)
                }

                reviewsSection(detail)
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
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                Text(String(format: "%.1f / 5", viewModel.summary.rating))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.98, green: 0.88, blue: 0.63), in: Capsule())
            .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))

            if let userRating = viewModel.userRating {
                Text("Your rating: \(String(format: "%.1f", userRating))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var memberships: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.summary.memberships, id: \.self) { membership in
                Text(membership.rawValue)
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
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(detail.photos) { photo in
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

                            if let caption = photo.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let author = photo.uploadedBy, !author.isEmpty {
                                Text("by \(author)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listRowBackground(Color.clear)
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

    private func reviewsSection(_ detail: ParkDetail) -> some View {
        Section("Recent Reviews") {
            if detail.reviews.isEmpty {
                Text("No reviews yet. Be the first to share your stay!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(detail.reviews) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                Text(String(format: "%.1f", review.rating))
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))

                            Spacer()

                            Text(review.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(review.comment)
                            .font(.body)
                        Text("— \(review.authorName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listRowBackground(Color.clear)
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
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
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

    private func loadPreview(for item: PhotosPickerItem?) {
        guard let item else {
            selectedPhotoData = nil
            selectedPhotoPreview = nil
            return
        }

        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedPhotoData = data
#if canImport(UIKit)
                        if let uiImage = UIImage(data: data) {
                            selectedPhotoPreview = Image(uiImage: uiImage)
                        } else {
                            selectedPhotoPreview = nil
                        }
#else
                        selectedPhotoPreview = nil
#endif
                    }
                }
            } catch {
                await MainActor.run {
                    viewModel.alertMessage = error.userFacingMessage
                }
            }
        }
    }
}

#Preview {
    let park = Park.sampleData[0]
    let detail = ParkDetail(
        summary: park,
        photos: [],
        amenities: park.amenities,
        notes: park.featuredNotes,
        reviews: [],
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

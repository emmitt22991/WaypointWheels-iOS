import SwiftUI
import PhotosUI

struct ParkDetailView: View {
    @StateObject private var viewModel: ParkDetailViewModel
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingPhotoGallery = false
    @State private var photoGalleryIndex = 0
    @State private var showingCommunityPhotos = false
    
    init(parkID: UUID,
         initialSummary: Park,
         service: ParksService,
         onParkUpdated: @escaping (Park) -> Void,
         prefetchedDetail: ParkDetail? = nil) {
        _viewModel = StateObject(wrappedValue: ParkDetailViewModel(
            parkID: parkID,
            initialSummary: initialSummary,
            service: service,
            onParkUpdated: onParkUpdated,
            prefetchedDetail: prefetchedDetail
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                parkInfoSection
                
                Divider()
                
                ratingSection
                
                Divider()
                
                reviewSection
                
                // PHOTOS SECTION - Show existing photos FIRST
                if let detail = viewModel.detail {
                    if !detail.familyPhotos.isEmpty {
                        Divider()
                        familyPhotosSection
                    }
                }
                
                // UPLOAD SECTION - Then show upload UI
                Divider()
                photoUploadSection
            }
            .padding()
        }
        .navigationTitle(viewModel.summary.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadParkIfNeeded()
        }
        .alert(viewModel.alertMessage ?? "", isPresented: .constant(viewModel.alertMessage != nil)) {
            Button("OK") {
                viewModel.alertMessage = nil
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self) {
                    let filename = newItem.itemIdentifier ?? "photo.jpg"
                    await viewModel.uploadPhoto(data: data, filename: filename)
                }
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showingPhotoGallery) {
            if let detail = viewModel.detail {
                PhotoGalleryView(
                    photos: detail.familyPhotos,
                    initialIndex: photoGalleryIndex,
                    showFamilyOnly: true
                )
            }
        }
        .fullScreenCover(isPresented: $showingCommunityPhotos) {
            if let detail = viewModel.detail {
                PhotoGalleryView(
                    photos: detail.communityPhotos,
                    initialIndex: 0,
                    showFamilyOnly: false
                )
            }
        }
    }
    
    private var parkInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.summary.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("\(viewModel.summary.city), \(viewModel.summary.state)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !viewModel.summary.memberships.isEmpty {
                HStack(spacing: 6) {
                    ForEach(viewModel.summary.memberships, id: \.id) { membership in
                        Text(membership.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(membership.badgeColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(membership.badgeColor)
                    }
                }
                .padding(.top, 4)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text(String(format: "%.1f", viewModel.summary.familyRating))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
                    
                    Text("Family Rating")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if let communityRating = viewModel.summary.communityRating {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.caption)
                            Text(String(format: "%.1f", communityRating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)
                        
                        Text("Community Rating")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RATE THIS PARK")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Slider(value: $viewModel.ratingDraft, in: 0...5, step: 0.5)
                Text("Selected: \(String(format: "%.1f", viewModel.ratingDraft))★")
                    .font(.subheadline)
            }
            
            Button {
                Task {
                    await viewModel.submitRating()
                }
            } label: {
                HStack {
                    if viewModel.isSubmittingRating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "star.fill")
                        Text("Submit Rating")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isSubmittingRating || viewModel.ratingDraft == 0)
        }
    }
    
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEAVE A REVIEW")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let userRating = viewModel.userRating {
                Text("Your review will use your rating of \(String(format: "%.1f", userRating))★.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            TextEditor(text: $viewModel.reviewDraft)
                .frame(height: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Button {
                Task {
                    await viewModel.submitReview()
                }
            } label: {
                HStack {
                    if viewModel.isSubmittingReview {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bubble.left.fill")
                        Text("Post Review")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isSubmittingReview || viewModel.reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            if let detail = viewModel.detail, !detail.familyReviews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RECENT REVIEWS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    ForEach(detail.familyReviews.prefix(3)) { review in
                        ReviewRow(review: review)
                    }
                }
            }
        }
    }
    
    // MARK: - Family Photos Section (Display existing photos)
    private var familyPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("FAMILY PHOTOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Link to view ALL community photos
                if let detail = viewModel.detail, !detail.communityPhotos.isEmpty {
                    Button {
                        showingCommunityPhotos = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("View All Community Photos")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            
            // Debug info - remove this after testing
            if let detail = viewModel.detail {
                Text("Loaded \(detail.familyPhotos.count) family photos")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            // Photo grid
            if let detail = viewModel.detail {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(Array(detail.familyPhotos.enumerated()), id: \.element.id) { index, photo in
                        PhotoThumbnail(photo: photo)
                            .onTapGesture {
                                photoGalleryIndex = index
                                showingPhotoGallery = true
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Photo Upload Section
    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SHARE A PHOTO")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField("Caption (optional)", text: $viewModel.photoCaption)
                .textFieldStyle(.roundedBorder)
            
            Button {
                showingPhotoPicker = true
            } label: {
                HStack {
                    if viewModel.isUploadingPhoto {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "photo.fill")
                        Text("Upload Photo")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isUploadingPhoto)
        }
    }
}

struct ReviewRow: View {
    let review: ParkDetail.Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(review.authorName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(String(format: "%.1f", review.rating))
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }
            
            Text(review.comment)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(review.formattedDate)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PhotoThumbnail: View {
    let photo: ParkDetail.Photo
    
    var body: some View {
        AsyncImage(url: photo.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
            case .failure:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 120)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                            Text("Failed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
            case .empty:
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: 120)
                    .overlay {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
            @unknown default:
                EmptyView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ParkDetailView(
            parkID: Park.sampleData[0].id,
            initialSummary: Park.sampleData[0],
            service: ParksService(),
            onParkUpdated: { _ in }
        )
    }
}

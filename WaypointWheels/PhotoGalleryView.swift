import SwiftUI

/// Full-screen photo gallery with navigation between photos
struct PhotoGalleryView: View {
    let photos: [ParkDetail.Photo]
    let initialIndex: Int
    let showFamilyOnly: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    
    init(photos: [ParkDetail.Photo], initialIndex: Int = 0, showFamilyOnly: Bool = true) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.showFamilyOnly = showFamilyOnly
        _currentIndex = State(initialValue: initialIndex)
    }
    
    var currentPhoto: ParkDetail.Photo {
        photos[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZoomablePhotoView(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(currentIndex + 1) of \(photos.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    if let caption = currentPhoto.caption {
                        Text(caption)
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                    
                    if let uploadedBy = currentPhoto.uploadedBy {
                        Text("Uploaded by \(uploadedBy)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial.opacity(0.8))
            }
        }
    }
}

/// Zoomable photo view with pinch-to-zoom and double-tap
struct ZoomablePhotoView: View {
    let photo: ParkDetail.Photo
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: photo.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), 4.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale <= 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    
                case .failure:
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Failed to load image")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    PhotoGalleryView(
        photos: [
            ParkDetail.Photo(
                id: UUID(),
                imageURL: URL(string: "https://waypointwheels.com/uploads/park_photos/sample.jpg")!,
                caption: "Beautiful sunset at the campground",
                uploadedBy: "John Doe",
                isFamilyPhoto: true
            )
        ],
        initialIndex: 0,
        showFamilyOnly: true
    )
}

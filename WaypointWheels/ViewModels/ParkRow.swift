import SwiftUI

struct ParkRow: View {
    let park: Park
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(park.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("\(park.city), \(park.state)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text(String(format: "%.1f", park.familyRating))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
                    
                    if let communityRating = park.communityRating {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.caption)
                            Text(String(format: "%.1f", communityRating))
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            if !park.memberships.isEmpty {
                HStack(spacing: 6) {
                    ForEach(park.memberships, id: \.id) { membership in
                        Text(membership.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(membership.badgeColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(membership.badgeColor)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        ParkRow(park: Park.sampleData[0])
        ParkRow(park: Park.sampleData[1])
    }
}

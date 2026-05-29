import SwiftUI
import Combine
import Foundation

struct CollectionSectionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

struct CollectionStickyHeader: View {
    let title: String
    let systemImage: String
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CollectionAssetGrid: View {
    let items: [BridgeCollectionItem]
    let emptyTitle: String

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 12)
    ]

    var body: some View {
        if items.isEmpty {
            CollectionEmptyState(title: emptyTitle, systemImage: "square.grid.2x2")
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    VStack(spacing: 8) {
                        AsyncImage(url: item.iconURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            default:
                                Image(systemName: "photo")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 72)

                        Text(item.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct CollectionEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

extension View {
    func collectionDisclosureStyle() -> some View {
        padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    func collectionSectionContentStyle() -> some View {
        padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

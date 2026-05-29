import SwiftUI
import Combine
import Foundation

struct FriendListView: View {
    @ObservedObject var bridge: PCBridgeClient
    @State private var isSelectingFavorites = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Friends")
                            .font(.largeTitle.bold())

                        Spacer()

                        Button {
                            isSelectingFavorites = true
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Select favorite friends")
                    }

                    if bridge.favoriteFriends.isEmpty {
                        ContentUnavailableView(
                            "No Favorite Friends",
                            systemImage: "star",
                            description: Text("Tap plus to choose friends whose ranks you want to track.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(bridge.favoriteFriends) { friend in
                                NavigationLink {
                                    FriendCareerSummaryView(friend: friend)
                                } label: {
                                    FriendRow(friend: friend)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let friends = bridge.friends, friends.friends.isEmpty {
                        ContentUnavailableView(
                            "No Friends Loaded",
                            systemImage: "person.2.slash",
                            description: Text("Refresh the current player data to load your friend list.")
                        )
                    }

                    if let friendsErrorMessage = bridge.friendsErrorMessage {
                        Text(friendsErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .sheet(isPresented: $isSelectingFavorites) {
                FriendFavoritePicker(bridge: bridge)
            }
        }
    }
}

struct FriendFavoritePicker: View {
    @ObservedObject var bridge: PCBridgeClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let friends = bridge.friends {
                    ForEach(friends.friends) { friend in
                        Button {
                            bridge.toggleFavoriteFriend(friend)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(friend.gameName)#\(friend.tagLine)")
                                        .font(.body)
                                    Text(friend.puuid)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                if bridge.favoriteFriendIDs.contains(friend.puuid) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ContentUnavailableView(
                        "Friend List Empty",
                        systemImage: "person.2",
                        description: Text("Refresh the current player data first.")
                    )
                }
            }
            .navigationTitle("Favorite Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm") {
                        Task {
                            await bridge.loadFavoriteFriendRanks()
                            await bridge.loadFavoriteFriendStatuses()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct FriendRow: View {
    let friend: BridgeFriend

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    RankIconView(mmr: friend.mmr)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(friend.gameName)#\(friend.tagLine)")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if let mmr = friend.mmr {
                        Text(mmr.rankName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let mmr = friend.mmr, mmr.hasRank {
                        HStack(spacing: 10) {
                            Text("\(mmr.rankedRating) RR")
                            Text("\(mmr.numberOfWins) wins")
                            if mmr.leaderboardRank > 0 {
                                Text("#\(mmr.leaderboardRank)")
                            }
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    } else if friend.mmr != nil {
                        Text("Unrated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if friend.mmrError != nil {
                        Text(friend.rankUnavailableText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(friend.puuid)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary.opacity(0.72))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 8)

                if let mmr = friend.mmr, mmr.hasRank {
                    RRHistoryColumn(mmr: mmr)
                }
            }

            if friend.status?.isOnline == true {
                Circle()
                    .fill(.green)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .padding(12)
                    .accessibilityLabel("Online")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FriendCareerSummaryView: View {
    let friend: BridgeFriend

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    RankIconView(mmr: friend.mmr)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(friend.gameName)#\(friend.tagLine)")
                            .font(.title2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if let mmr = friend.mmr {
                            Text(mmr.rankName)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                if let mmr = friend.mmr, mmr.hasRank {
                    HStack(spacing: 14) {
                        CareerMetricView(title: "RR", value: "\(mmr.rankedRating)")
                        CareerMetricView(title: "Wins", value: "\(mmr.numberOfWins)")
                        if mmr.leaderboardRank > 0 {
                            CareerMetricView(title: "Rank", value: "#\(mmr.leaderboardRank)")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Act Rank")
                            .font(.headline)

                        if mmr.acts.isEmpty {
                            ActRankActSummaryView(act: mmr.currentActFallback, mmr: mmr)
                        } else {
                            ForEach(mmr.acts) { act in
                                ActRankActSummaryView(act: act, mmr: mmr)
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                } else if let error = friend.mmrError {
                    ContentUnavailableView(
                        "Career Unavailable",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(error)
                    )
                } else {
                    ContentUnavailableView(
                        "Career Not Loaded",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Refresh friend ranks to load this player's career summary.")
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Career Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CareerMetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(minWidth: 72, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ActRankCareerPreview: View {
    let mmr: BridgeFriendMMR
    let mode: ActRankBadgeMode

    var body: some View {
        VStack(spacing: 8) {
            ActRankBadgeView(mmr: mmr, mode: mode)

            Text(mode.title(for: mmr.actRankBadgeCells.count))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct ActRankActSummaryView: View {
    let act: BridgeActRankAct
    let mmr: BridgeFriendMMR

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(act.name)
                        .font(.subheadline.weight(.semibold))

                    Text("\(act.numberOfWins) wins")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if act.isCurrent {
                    Text("Current")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
            }

            HStack(alignment: .top, spacing: 18) {
                ActRankBadgeView(cells: act.badgeCells, mode: .compact)

                VStack(alignment: .leading, spacing: 6) {
                    if act.winsByTier.isEmpty {
                        Text("No ranked wins")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(act.winsByTier) { winTier in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(winTier.color)
                                    .frame(width: 8, height: 8)

                                Text(winTier.rankName)
                                    .font(.caption.weight(.semibold))

                                Spacer(minLength: 8)

                                Text("\(winTier.wins)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if act.isCurrent {
                RecentRRChangesView(mmr: mmr)
            }
        }
        .padding(.vertical, 6)
    }
}

struct RecentRRChangesView: View {
    let mmr: BridgeFriendMMR

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent RR")
                .font(.subheadline.weight(.semibold))

            if mmr.lastMatchRRChanges.isEmpty {
                Text("No recent RR changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mmr.lastMatchRRChanges.prefix(5)) { rrChange in
                    HStack {
                        Text(rrChange.compactDisplayText)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(rrChange.tint)

                        Spacer()

                        if let tierAfter = rrChange.tierAfter {
                            Text("Tier \(tierAfter)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

enum ActRankBadgeMode: CaseIterable {
    case peak
    case compact
    case full

    func title(for winCount: Int) -> String {
        switch self {
        case .peak:
            return "Peak"
        case .compact:
            let slots = rowSizes(for: winCount).reduce(0, +)
            return "\(slots) slots"
        case .full:
            let slots = rowSizes(for: winCount).reduce(0, +)
            return "\(slots) slots"
        }
    }

    func badgeSize(for winCount: Int) -> CGSize {
        switch self {
        case .peak:
            return CGSize(width: 54, height: 54)
        case .compact:
            return CGSize(width: 82, height: 74)
        case .full:
            let extraRows = max(0, rowSizes(for: winCount).count - 10)
            return CGSize(
                width: 112 + CGFloat(extraRows * 10),
                height: 100 + CGFloat(extraRows * 9)
            )
        }
    }

    var innerScale: CGSize {
        switch self {
        case .peak:
            return CGSize(width: 0.46, height: 0.42)
        case .compact:
            return CGSize(width: 0.74, height: 0.64)
        case .full:
            return CGSize(width: 0.76, height: 0.66)
        }
    }

    func rowSizes(for winCount: Int) -> [Int] {
        switch self {
        case .peak:
            return [1]
        case .compact:
            let cappedWinCount = max(1, min(winCount, 25))
            let rowCount = max(1, min(5, Int(ceil(sqrt(Double(cappedWinCount))))))
            return (0..<rowCount).map { rowIndex in
                rowIndex * 2 + 1
            }
        case .full:
            let cappedWinCount = max(1, min(winCount, 225))
            let rowCount = max(1, min(15, Int(ceil(sqrt(Double(cappedWinCount))))))
            return (0..<rowCount).map { rowIndex in
                rowIndex * 2 + 1
            }
        }
    }
}

struct ActRankDevelopmentBadgeBox: View {
    let mmr: BridgeFriendMMR

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(ActRankBadgeMode.allCases, id: \.self) { mode in
                VStack(spacing: 2) {
                    ActRankBadgeView(mmr: mmr, mode: mode)

                    Text(mode.title(for: mmr.actRankBadgeCells.count))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Act rank development badge states")
    }
}

struct ActRankBadgeView: View {
    let cells: [BridgeActRankBadgeCell]
    let mode: ActRankBadgeMode

    init(mmr: BridgeFriendMMR, mode: ActRankBadgeMode) {
        self.cells = mmr.actRankBadgeCells
        self.mode = mode
    }

    init(cells: [BridgeActRankBadgeCell], mode: ActRankBadgeMode) {
        self.cells = cells
        self.mode = mode
    }

    private var badgeWidth: CGFloat {
        mode.badgeSize(for: cells.count).width
    }

    private var badgeHeight: CGFloat {
        mode.badgeSize(for: cells.count).height
    }

    var body: some View {
        ZStack {
            ActRankFrame()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.50, green: 0.52, blue: 0.56),
                            Color(red: 0.18, green: 0.20, blue: 0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    ActRankFrame()
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                }

            ActRankMeshView(cells: displayCells, rowSizes: rowSizes)
                .frame(width: badgeWidth * mode.innerScale.width, height: badgeHeight * mode.innerScale.height)
                .offset(y: badgeHeight * 0.06)
                .clipShape(ActRankFrame(insetScale: 0))
        }
        .frame(width: badgeWidth, height: badgeHeight)
        .accessibilityLabel("Act rank badge")
    }

    private var displayCells: [BridgeActRankBadgeCell] {
        switch mode {
        case .peak:
            return Array(cells.prefix(1))
        case .compact, .full:
            return Array(cells.prefix(rowSizes.reduce(0, +)))
        }
    }

    private var rowSizes: [Int] {
        mode.rowSizes(for: cells.count)
    }
}

struct ActRankMeshView: View {
    let cells: [BridgeActRankBadgeCell]
    let rowSizes: [Int]

    var body: some View {
        GeometryReader { geometry in
            let slices = rowSlices
            let baseCount = CGFloat(max(rowSizes.last ?? 1, 1))
            let rowCount = CGFloat(max(rowSizes.count, 1))
            let cellWidth = geometry.size.width / baseCount
            let cellHeight = geometry.size.height / rowCount
            let overlap: CGFloat = 0.38
            let xStep = cellWidth * (1 - overlap)
            let yStep = cellHeight * 0.72

            ZStack {
                ForEach(slices.indices, id: \.self) { rowIndex in
                    ForEach(Array(slices[rowIndex].enumerated()), id: \.offset) { columnIndex, cell in
                        let rowWidth = xStep * CGFloat(rowSizes[rowIndex] - 1) + cellWidth
                        let meshHeight = yStep * CGFloat(max(rowSizes.count - 1, 0)) + cellHeight
                        let x = geometry.size.width / 2 - rowWidth / 2 + cellWidth / 2 + xStep * CGFloat(columnIndex)
                        let y = geometry.size.height / 2 - meshHeight / 2 + cellHeight / 2 + yStep * CGFloat(rowIndex)

                        ActRankCellView(
                            cell: cell,
                            pointsUp: columnIndex.isMultiple(of: 2),
                            width: cellWidth,
                            height: cellHeight
                        )
                        .position(x: x, y: y)
                    }
                }
            }
        }
    }

    private var rowSlices: [[BridgeActRankBadgeCell?]] {
        var remainingCells = Array(cells.prefix(rowSizes.reduce(0, +)))
        var rows: [[BridgeActRankBadgeCell?]] = []

        for rowSize in rowSizes {
            var rowCells: [BridgeActRankBadgeCell?] = Array(remainingCells.prefix(rowSize))
            if rowCells.count < rowSize {
                rowCells.append(contentsOf: Array(repeating: nil, count: rowSize - rowCells.count))
            }
            rows.append(rowCells)
            remainingCells.removeFirst(min(rowSize, remainingCells.count))
        }

        return rows
    }
}

struct ActRankCellView: View {
    let cell: BridgeActRankBadgeCell?
    let pointsUp: Bool
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if cell == nil {
                Color.clear
            } else {
                if let iconURL {
                    AsyncImage(url: iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        default:
                            fallbackTriangle
                        }
                    }
                } else {
                    fallbackTriangle
                }
            }
        }
        .frame(width: width, height: height)
        .shadow(color: shadowColor, radius: 0.8, y: 0.4)
    }

    private var iconURL: URL? {
        guard let cell else {
            return nil
        }

        return pointsUp ? cell.rankTriangleUpIconURL : cell.rankTriangleDownIconURL
    }

    private var fallbackTriangle: some View {
        Triangle(pointsUp: pointsUp)
            .fill(fillColor)
            .overlay {
                Triangle(pointsUp: pointsUp)
                    .stroke(strokeColor, lineWidth: 0.45)
            }
    }

    private var fillColor: Color {
        cell?.color ?? Color(red: 0.13, green: 0.15, blue: 0.18)
    }

    private var strokeColor: Color {
        cell == nil ? .white.opacity(0.12) : .white.opacity(0.45)
    }

    private var shadowColor: Color {
        cell?.color.opacity(0.28) ?? .clear
    }
}

struct ActRankFrame: Shape {
    var insetScale: CGFloat = 0.08

    func path(in rect: CGRect) -> Path {
        let inset = min(rect.width, rect.height) * insetScale
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.closeSubpath()
        return path
    }
}

struct Triangle: Shape {
    var pointsUp = true

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if pointsUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}

struct RRHistoryColumn: View {
    let mmr: BridgeFriendMMR

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Last 5")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if !mmr.lastMatchRRChanges.isEmpty {
                ForEach(mmr.lastMatchRRChanges.prefix(5)) { rrChange in
                    Text(rrChange.compactDisplayText)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(rrChange.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else if let lastMatchRRChange = mmr.lastMatchRRChange {
                Text(mmr.lastMatchRRChangeText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(lastMatchRRChange >= 0 ? .green : .red)
                    .lineLimit(1)
            } else if let lastMatchRRChangesError = mmr.lastMatchRRChangesError {
                Text("RR failed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityLabel("RR history failed: \(lastMatchRRChangesError)")
            } else {
                Text("No RR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: 92, alignment: .trailing)
    }
}

struct RankIconView: View {
    let mmr: BridgeFriendMMR?

    var body: some View {
        ZStack {
            if let iconURL = mmr?.rankIconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 48, height: 48)
    }

    private var fallbackIcon: some View {
        Image(systemName: mmr?.hasRank == true ? "triangle.fill" : "minus.circle")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

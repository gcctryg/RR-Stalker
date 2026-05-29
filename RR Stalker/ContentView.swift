//
//  ContentView.swift
//  RR Stalker
//
//  Created by Xuelu Feng on 5/18/26.
//

import SwiftUI
import Combine
import Foundation

struct ContentView: View {
    @StateObject private var bridge = PCBridgeClient()

    var body: some View {
        TabView {
            ProfileView(bridge: bridge)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }

            CollectionsView(bridge: bridge)
                .tabItem {
                    Label("Collections", systemImage: "square.grid.2x2")
                }

            FriendListView(bridge: bridge)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }

            EsportView()
                .tabItem {
                    Label("eSport", systemImage: "trophy")
                }
        }
        .task {
            await bridge.loadPlayer()
        }
    }
}

struct LoadoutView: View {
    @ObservedObject var bridge: PCBridgeClient
    @State private var selectedGun: BridgeLoadoutGun?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Loadout")
                    .font(.largeTitle.bold())

                if let loadout = bridge.loadout, !loadout.guns.isEmpty {
                    LoadoutOverview(loadout: loadout) { gun in
                        selectedGun = gun
                    }
                } else if bridge.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                } else {
                    ContentUnavailableView(
                        "No Loadout",
                        systemImage: "scope",
                        description: Text("Refresh profile data to load your equipped weapons.")
                    )
                }

                if let loadoutErrorMessage = bridge.loadoutErrorMessage {
                    Text(loadoutErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .sheet(item: $selectedGun) { gun in
            LoadoutWeaponDetailView(bridge: bridge, gun: gun)
        }
    }
}

struct CollectionsView: View {
    @ObservedObject var bridge: PCBridgeClient
    @State private var selectedGun: BridgeLoadoutGun?
    @State private var isShowingSkins = true
    @State private var isShowingSprays = false
    @State private var isShowingCards = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                        Text("Collections")
                            .font(.largeTitle.bold())
                            .id("collections-title")

                        Section {
                            if isShowingSkins {
                                VStack(alignment: .leading, spacing: 12) {
                                    if let loadout = bridge.loadout, !loadout.guns.isEmpty {
                                        LoadoutOverview(loadout: loadout) { gun in
                                            selectedGun = gun
                                        }
                                    } else {
                                        CollectionEmptyState(title: "No skins loaded", systemImage: "scope")
                                    }
                                }
                                .collectionSectionContentStyle()
                            }
                        } header: {
                            CollectionStickyHeader(title: "Skins", systemImage: "scope", isExpanded: isShowingSkins) {
                                toggleCollectionSection(id: "skins-header", isExpanded: $isShowingSkins, proxy: proxy)
                            }
                            .id("skins-header")
                        }

                        Section {
                            if isShowingSprays {
                                CollectionAssetGrid(items: bridge.collections?.sprays ?? [], emptyTitle: "No sprays loaded")
                                    .collectionSectionContentStyle()
                            }
                        } header: {
                            CollectionStickyHeader(title: "Sprays", systemImage: "paintpalette", isExpanded: isShowingSprays) {
                                toggleCollectionSection(id: "sprays-header", isExpanded: $isShowingSprays, proxy: proxy)
                            }
                            .id("sprays-header")
                        }

                        Section {
                            if isShowingCards {
                                CollectionAssetGrid(items: bridge.collections?.playerCards ?? [], emptyTitle: "No player cards loaded")
                                    .collectionSectionContentStyle()
                            }
                        } header: {
                            CollectionStickyHeader(title: "Player Cards", systemImage: "rectangle.portrait", isExpanded: isShowingCards) {
                                toggleCollectionSection(id: "cards-header", isExpanded: $isShowingCards, proxy: proxy)
                            }
                            .id("cards-header")
                        }

                        if let loadoutErrorMessage = bridge.loadoutErrorMessage {
                            Text(loadoutErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }

                        if let collectionsErrorMessage = bridge.collectionsErrorMessage {
                            Text(collectionsErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                }
            }
            .sheet(item: $selectedGun) { gun in
                LoadoutWeaponDetailView(bridge: bridge, gun: gun)
            }
        }
    }

    private func toggleCollectionSection(id: String, isExpanded: Binding<Bool>, proxy: ScrollViewProxy) {
        let wasExpanded = isExpanded.wrappedValue

        if wasExpanded {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                proxy.scrollTo(id, anchor: .top)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isExpanded.wrappedValue = false
                }
            }
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                isExpanded.wrappedValue = true
            }
        }
    }
}

struct ProfileView: View {
    @ObservedObject var bridge: PCBridgeClient

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProfileNavigationHeader(bridge: bridge)

                    CurrentSeasonPeakCard(mmr: bridge.currentPlayerMMR, errorMessage: bridge.currentPlayerMMRErrorMessage)

                    if let storefront = bridge.storefront {
                        ShopSection(storefront: storefront, wallet: bridge.wallet)
                    }

                    if let errorMessage = bridge.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if let walletErrorMessage = bridge.walletErrorMessage {
                        Text(walletErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    if let storefrontErrorMessage = bridge.storefrontErrorMessage {
                        Text(storefrontErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        }
    }
}

struct EsportView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("eSport", systemImage: "trophy", description: Text("This tab is empty for now."))
        }
    }
}

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

struct SettingsView: View {
    @ObservedObject var bridge: PCBridgeClient

    var body: some View {
        NavigationStack {
            List {
                Section("Bridge") {
                    Text(bridge.baseURL.absoluteString)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)

                    Text(bridge.isServerOnline ? "Server Online" : "Server Offline")
                        .font(.footnote)
                        .foregroundStyle(bridge.isServerOnline ? .green : .red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct ServerStatusPill: View {
    @ObservedObject var bridge: PCBridgeClient

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(bridge.isServerOnline ? .green : .red)
                .frame(width: 9, height: 9)

            Text(bridge.isServerOnline ? "Server Online" : "Server Offline")
                .font(.caption.weight(.semibold))

            if let lastFetchText = bridge.lastFetchText {
                Text(lastFetchText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

struct ProfileNavigationHeader: View {
    @ObservedObject var bridge: PCBridgeClient
    @State private var isShowingSettings = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    Task {
                        await bridge.loadPlayer()
                    }
                } label: {
                    ZStack {
                        Image(systemName: "arrow.clockwise")
                            .opacity(bridge.isLoading ? 0 : 1)

                        if bridge.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(bridge.isLoading)
                .accessibilityLabel(bridge.isLoading ? "Loading player data" : "Refresh player data")

                Circle()
                    .fill(bridge.isServerOnline ? .green : .red)
                    .frame(width: 12, height: 12)
                    .accessibilityLabel(bridge.isServerOnline ? "Server online" : "Server offline")
            }
            .frame(width: 82, alignment: .leading)

            VStack(spacing: 3) {
                if let player = bridge.player {
                    Text("\(player.gameName)#\(player.tagLine)")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("Level \(player.level)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("RR Stalker")
                        .font(.headline.weight(.semibold))

                    Text(bridge.isServerOnline ? "Player not loaded" : "Server offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 82, alignment: .trailing)
            .accessibilityLabel("Settings")
        }
        .padding(.vertical, 10)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(bridge: bridge)
        }
    }
}

struct HeaderBanner: View {
    @ObservedObject var bridge: PCBridgeClient
    @State private var isShowingSettings = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("RR Stalker")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 2) {
                    ServerStatusPill(bridge: bridge)

                    Text(bridge.baseURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 12)

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Settings")

            Button {
                Task {
                    await bridge.loadPlayer()
                }
            } label: {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .opacity(bridge.isLoading ? 0 : 1)

                    if bridge.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(bridge.isLoading)
            .accessibilityLabel(bridge.isLoading ? "Loading player data" : "Refresh player data")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(bridge: bridge)
        }
    }
}

struct WalletSummaryCard: View {
    let wallet: BridgeWallet?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(BridgeWalletItem.orderedCurrencyPlaceholders(wallet: wallet)) { item in
                WalletCurrencyView(item: item)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct WalletCurrencyView: View {
    let item: BridgeWalletItem

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: item.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: item.fallbackSystemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)

            Text("\(item.amount)")
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(item.shortName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WalletHeaderSummary: View {
    let wallet: BridgeWallet?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(BridgeWalletItem.orderedCurrencyPlaceholders(wallet: wallet)) { item in
                HStack(spacing: 4) {
                    AsyncImage(url: item.iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        default:
                            Image(systemName: item.fallbackSystemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.gray)
                        }
                    }
                    .frame(width: 17, height: 17)

                    Text("\(item.amount)")
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.gray.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(walletAccessibilityText)
    }

    private var walletAccessibilityText: String {
        BridgeWalletItem
            .orderedCurrencyPlaceholders(wallet: wallet)
            .map { "\($0.shortName) \($0.amount)" }
            .joined(separator: ", ")
    }
}

struct CurrentSeasonPeakCard: View {
    let mmr: BridgeFriendMMR?
    let errorMessage: String?

    var body: some View {
        Group {
            if let mmr, mmr.hasRank {
                let act = mmr.acts.first(where: \.isCurrent) ?? mmr.currentActFallback

                HStack(spacing: 14) {
                    ActRankBadgeView(cells: act.badgeCells, mode: .peak)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Season Peak")
                            .font(.headline)

                        Text(act.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Text(mmr.rankName)
                            Text("\(act.numberOfWins) wins")
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if let errorMessage {
                Text("Current season peak unavailable: \(errorMessage)")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

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

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
        }
    }
}

struct ShopSection: View {
    let storefront: BridgeStorefront
    let wallet: BridgeWallet?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("SHOP")
                    .font(.headline)

                Text(storefront.remainingTimeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                WalletHeaderSummary(wallet: wallet)
            }

            ForEach(storefront.offers) { offer in
                ShopOfferRow(offer: offer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShopOfferRow: View {
    let offer: BridgeStorefrontOffer
    @State private var didRevealCard = false

    private var shouldReveal: Bool {
        didRevealCard
    }

    var body: some View {
        Button {
            if !shouldReveal {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    didRevealCard = true
                }
            }
        } label: {
            ZStack {
                if shouldReveal {
                    revealedContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .scale(scale: 1.04).combined(with: .opacity)
                        ))
                } else {
                    hiddenContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .scale(scale: 0.92).combined(with: .opacity)
                        ))
                }
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shouldReveal ? "\(offer.name), \(offer.price) VP" : "Hidden shop offer")
    }

    private var revealedContent: some View {
        HStack(spacing: 12) {
            ShopOfferImage(iconURL: offer.iconURL)

            VStack(alignment: .leading, spacing: 6) {
                Text(offer.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(offer.price) VP")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(minHeight: 58)
    }

    private var hiddenContent: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tierColor.opacity(0.24))

                tierIcon
            }
            .frame(width: 86, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text(offer.contentTierName ?? "Hidden Offer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Tap to reveal")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(minHeight: 58)
    }

    @ViewBuilder
    private var tierIcon: some View {
        if let tierIconURL = offer.contentTierIconURL {
            AsyncImage(url: tierIconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: "questionmark")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 28, height: 28)
        } else {
            Image(systemName: "questionmark")
                .font(.title2.weight(.semibold))
                .foregroundStyle(tierColor)
        }
    }

    private var tierColor: Color {
        offer.contentTierColorValue ?? .secondary
    }

    private var cardBackgroundColor: Color {
        if shouldReveal {
            return tierColor.opacity(0.28)
        }

        return tierColor.opacity(0.22)
    }

    private var cardBorderColor: Color {
        if shouldReveal {
            return .secondary.opacity(0.18)
        }

        return tierColor.opacity(0.42)
    }
}

struct ShopOfferImage: View {
    let iconURL: URL?

    var body: some View {
        AsyncImage(url: iconURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            default:
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 86, height: 58)
    }
}

struct LoadoutOverview: View {
    let loadout: BridgeLoadout
    let onSelect: (BridgeLoadoutGun) -> Void

    private let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            mainWeaponsSection
            sniperSection
            weaponSection(title: "SMGs", guns: loadout.guns(named: ["Stinger", "Spectre"]))
            weaponSection(title: "Shotguns", guns: loadout.guns(named: ["Bucky", "Judge"]))
            weaponSection(title: "Rifles", guns: loadout.guns(named: ["Bulldog", "Guardian"]))
            weaponSection(title: "Heavy", guns: loadout.guns(named: ["Ares", "Odin"]))
            weaponSection(title: "Sidearms", guns: loadout.guns(named: ["Classic", "Shorty", "Frenzy", "Ghost", "Sheriff"]))
        }
    }

    private var mainWeaponsSection: some View {
        LoadoutSectionContainer(title: "Main Weapons") {
            LazyVGrid(columns: twoColumns, spacing: 12) {
                ForEach(loadout.guns(named: ["Vandal", "Phantom"])) { gun in
                    loadoutButton(gun, style: .square)
                }
            }

            if let melee = loadout.gun(named: "Melee") {
                loadoutButton(melee, style: .rectangle)
            }
        }
    }

    private var sniperSection: some View {
        LoadoutSectionContainer(title: "Snipers") {
            LazyVGrid(columns: twoColumns, spacing: 12) {
                ForEach(loadout.guns(named: ["Marshal", "Outlaw"])) { gun in
                    loadoutButton(gun, style: .square)
                }
            }

            if let operatorGun = loadout.gun(named: "Operator") {
                loadoutButton(operatorGun, style: .rectangle)
            }
        }
    }

    @ViewBuilder
    private func weaponSection(title: String, guns: [BridgeLoadoutGun]) -> some View {
        if !guns.isEmpty {
            LoadoutSectionContainer(title: title) {
                LazyVGrid(columns: twoColumns, spacing: 12) {
                    ForEach(guns) { gun in
                        loadoutButton(gun, style: .square)
                    }
                }
            }
        }
    }

    private func loadoutButton(_ gun: BridgeLoadoutGun, style: LoadoutWeaponCardStyle) -> some View {
        Button {
            onSelect(gun)
        } label: {
            LoadoutWeaponCard(gun: gun, style: style)
        }
        .buttonStyle(.plain)
    }
}

struct LoadoutSectionContainer<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
    }
}

enum LoadoutWeaponCardStyle {
    case square
    case rectangle

    var imageHeight: CGFloat {
        switch self {
        case .square:
            return 72
        case .rectangle:
            return 92
        }
    }

    var cardHeight: CGFloat {
        switch self {
        case .square:
            return 134
        case .rectangle:
            return 154
        }
    }

    var textHeight: CGFloat {
        switch self {
        case .square:
            return 38
        case .rectangle:
            return 38
        }
    }
}

struct LoadoutWeaponCard: View {
    let gun: BridgeLoadoutGun
    var style: LoadoutWeaponCardStyle = .square

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                AsyncImage(url: gun.iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: "scope")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: style.imageHeight)

            VStack(alignment: .leading, spacing: 4) {
                Text(gun.displayWeaponName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(gun.displaySkinName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
            }
            .frame(height: style.textHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .frame(height: style.cardHeight, alignment: .topLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topLeading) {
            if let charmIconURL = gun.charmIconURL {
                AsyncImage(url: charmIconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 24, height: 24)
                .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let tierIconURL = gun.contentTierIconURL {
                AsyncImage(url: tierIconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: "diamond.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(gun.contentTierColorValue ?? .secondary)
                    }
                }
                .frame(width: 24, height: 24)
                .padding(8)
            }
        }
    }

    private var cardBackground: some ShapeStyle {
        (gun.contentTierColorValue ?? .secondary).opacity(0.18)
    }
}

struct LoadoutWeaponDetailView: View {
    @ObservedObject var bridge: PCBridgeClient
    @Environment(\.dismiss) private var dismiss
    let gun: BridgeLoadoutGun

    @State private var isShowingSkinPicker = false
    @State private var isShowingCharmPicker = false

    private var currentGun: BridgeLoadoutGun {
        bridge.loadout?.guns.first(where: { $0.id == gun.id }) ?? gun
    }

    private var canUseCharm: Bool {
        !currentGun.categoryKey.contains("melee") && !currentGun.weaponName.localizedCaseInsensitiveContains("melee")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button {
                    isShowingSkinPicker = true
                } label: {
                    LoadoutDetailCard(
                        title: "Current Skin",
                        name: currentGun.displaySkinName,
                        iconURL: currentGun.iconURL,
                        fallbackSystemImage: "scope",
                        accentColor: currentGun.contentTierColorValue ?? .secondary
                    )
                }
                .buttonStyle(.plain)

                if canUseCharm {
                    Button {
                        isShowingCharmPicker = true
                    } label: {
                        LoadoutDetailCard(
                            title: "Charm",
                            name: currentGun.charmName ?? "No Charm",
                            iconURL: currentGun.charmIconURL,
                            fallbackSystemImage: "circle.hexagongrid.fill",
                            accentColor: .secondary
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(currentGun.displayWeaponName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingSkinPicker) {
                LoadoutSkinPickerView(bridge: bridge, gun: currentGun)
            }
            .sheet(isPresented: $isShowingCharmPicker) {
                LoadoutCharmPickerView(bridge: bridge, gun: currentGun)
            }
        }
    }
}

struct LoadoutDetailCard: View {
    let title: String
    let name: String
    let iconURL: URL?
    let fallbackSystemImage: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.16))

                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: fallbackSystemImage)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
            }
            .frame(width: 112, height: 82)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.14), lineWidth: 1)
        }
    }
}

struct LoadoutSkinPickerView: View {
    @ObservedObject var bridge: PCBridgeClient
    @Environment(\.dismiss) private var dismiss
    let gun: BridgeLoadoutGun

    @State private var inventory: BridgeOwnedWeaponSkins?
    @State private var selectedSkin: BridgeOwnedWeaponSkin?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isEquipping = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let inventory {
                    if inventory.skins.isEmpty {
                        ContentUnavailableView(
                            "No Owned Skins",
                            systemImage: "scope",
                            description: Text("No owned skins were returned for \(gun.weaponName).")
                        )
                    } else {
                        List(inventory.skins) { skin in
                            Button {
                                selectedSkin = skin
                            } label: {
                                LoadoutSkinRow(
                                    skin: skin,
                                    isSelected: selectedSkin?.id == skin.id,
                                    isEquipped: skin.isEquipped
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                    }
                } else {
                    ContentUnavailableView(
                        "Skins Not Loaded",
                        systemImage: "scope",
                        description: Text("Pull to load owned skins.")
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Button {
                    Task {
                        await equipSelectedSkin()
                    }
                } label: {
                    if isEquipping {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(equipButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(equipButtonDisabled)
                .padding()
            }
            .navigationTitle(gun.weaponName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSkins()
            }
        }
    }

    private var equipButtonTitle: String {
        guard let selectedSkin else {
            return "Select a Skin"
        }

        return selectedSkin.isEquipped ? "Equipped" : "Equip"
    }

    private var equipButtonDisabled: Bool {
        selectedSkin == nil || selectedSkin?.isEquipped == true || isEquipping
    }

    private func loadSkins() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedInventory = try await bridge.loadOwnedWeaponSkins(for: gun)
            inventory = loadedInventory
            selectedSkin = loadedInventory.skins.first(where: \.isEquipped) ?? loadedInventory.skins.first
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func equipSelectedSkin() async {
        guard let skinToEquip = selectedSkin else {
            return
        }

        isEquipping = true
        errorMessage = nil

        do {
            try await bridge.equipWeaponSkin(skinToEquip, for: gun)
            inventory = try await bridge.loadOwnedWeaponSkins(for: gun)
            selectedSkin = inventory?.skins.first(where: \.isEquipped) ?? skinToEquip
        } catch {
            errorMessage = error.localizedDescription
        }

        isEquipping = false
    }
}

struct LoadoutSkinRow: View {
    let skin: BridgeOwnedWeaponSkin
    let isSelected: Bool
    let isEquipped: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: skin.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 74, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(skin.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(isEquipped ? "Equipped" : "Owned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEquipped {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isSelected {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct LoadoutCharmPickerView: View {
    @ObservedObject var bridge: PCBridgeClient
    @Environment(\.dismiss) private var dismiss
    let gun: BridgeLoadoutGun

    @State private var inventory: BridgeOwnedWeaponCharms?
    @State private var selectedCharm: BridgeOwnedWeaponCharm?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isEquipping = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let inventory {
                    if inventory.charms.isEmpty {
                        ContentUnavailableView(
                            "No Owned Charms",
                            systemImage: "circle.hexagongrid.fill",
                            description: Text("No owned charms were returned for \(gun.displayWeaponName).")
                        )
                    } else {
                        List(inventory.charms) { charm in
                            Button {
                                selectedCharm = charm
                            } label: {
                                LoadoutCharmRow(
                                    charm: charm,
                                    isSelected: selectedCharm?.id == charm.id,
                                    isEquipped: charm.isEquipped
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                    }
                } else {
                    ContentUnavailableView(
                        "Charms Not Loaded",
                        systemImage: "circle.hexagongrid.fill",
                        description: Text("Pull to load owned charms.")
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Button {
                    Task {
                        await equipSelectedCharm()
                    }
                } label: {
                    if isEquipping {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(equipButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(equipButtonDisabled)
                .padding()
            }
            .navigationTitle("\(gun.displayWeaponName) Charm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadCharms()
            }
        }
    }

    private var equipButtonTitle: String {
        guard let selectedCharm else {
            return "Select a Charm"
        }

        return selectedCharm.isEquipped ? "Equipped" : "Equip"
    }

    private var equipButtonDisabled: Bool {
        selectedCharm == nil || selectedCharm?.isEquipped == true || isEquipping
    }

    private func loadCharms() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedInventory = try await bridge.loadOwnedWeaponCharms(for: gun)
            inventory = loadedInventory
            selectedCharm = loadedInventory.charms.first(where: \.isEquipped) ?? loadedInventory.charms.first
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func equipSelectedCharm() async {
        guard let charmToEquip = selectedCharm else {
            return
        }

        isEquipping = true
        errorMessage = nil

        do {
            try await bridge.equipWeaponCharm(charmToEquip, for: gun)
            inventory = try await bridge.loadOwnedWeaponCharms(for: gun)
            selectedCharm = inventory?.charms.first(where: \.isEquipped) ?? charmToEquip
        } catch {
            errorMessage = error.localizedDescription
        }

        isEquipping = false
    }
}

struct LoadoutCharmRow: View {
    let charm: BridgeOwnedWeaponCharm
    let isSelected: Bool
    let isEquipped: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: charm.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(charm.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(isEquipped ? "Equipped" : "Owned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEquipped {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isSelected {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

@MainActor
final class PCBridgeClient: ObservableObject {
    private let favoriteFriendIDsKeyPrefix = "favoriteFriendIDs"
    private let cacheKey = "bridgeLastSnapshot"

    @Published var player: BridgePlayer?
    @Published var wallet: BridgeWallet?
    @Published var storefront: BridgeStorefront?
    @Published var currentPlayerMMR: BridgeFriendMMR?
    @Published var loadout: BridgeLoadout?
    @Published var collections: BridgeCollections?
    @Published var friends: BridgeFriends?
    @Published var favoriteFriendIDs: Set<String>
    @Published var favoriteFriendRanks: [String: BridgeFriendMMR] = [:]
    @Published var favoriteFriendRankErrors: [String: String] = [:]
    @Published var favoriteFriendStatuses: [String: BridgeFriendStatus] = [:]
    @Published var errorMessage: String?
    @Published var walletErrorMessage: String?
    @Published var storefrontErrorMessage: String?
    @Published var currentPlayerMMRErrorMessage: String?
    @Published var loadoutErrorMessage: String?
    @Published var collectionsErrorMessage: String?
    @Published var friendsErrorMessage: String?
    @Published var isLoading = false
    @Published var isServerOnline = false
    @Published var lastFetchedAt: Date?

    // Tailscale IP for the PC bridge.
    //let baseURL = URL(string: "http://100.114.128.21:3000")!
    //ip for home
    let baseURL = URL(string: "http://192.168.0.14:3000")!

    init() {
        favoriteFriendIDs = []
        loadCachedSnapshot()
    }

    var lastFetchText: String? {
        guard let lastFetchedAt else {
            return nil
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Last fetch \(formatter.localizedString(for: lastFetchedAt, relativeTo: Date()))"
    }

    var favoriteFriends: [BridgeFriend] {
        guard let friends else {
            return []
        }

        return friends.friends
            .filter { favoriteFriendIDs.contains($0.puuid) }
            .map { friend in
                var favorite = friend
                favorite.mmr = favoriteFriendRanks[friend.puuid]
                favorite.mmrError = favoriteFriendRankErrors[friend.puuid]
                favorite.status = favoriteFriendStatuses[friend.puuid]
                return favorite
            }
    }

    func loadPlayer() async {
        isLoading = true
        errorMessage = nil
        walletErrorMessage = nil
        storefrontErrorMessage = nil
        currentPlayerMMRErrorMessage = nil
        loadoutErrorMessage = nil
        collectionsErrorMessage = nil
        friendsErrorMessage = nil

        do {
            try await checkHealth()

            let url = baseURL.appending(path: "player")
            let loadedPlayer: BridgePlayer = try await fetchJSON(from: url)
            let previousPlayerPUUID = player?.puuid
            player = loadedPlayer
            loadFavoriteFriendIDs(for: loadedPlayer.puuid)
            if previousPlayerPUUID != loadedPlayer.puuid {
                favoriteFriendRanks = [:]
                favoriteFriendRankErrors = [:]
                favoriteFriendStatuses = [:]
                wallet = nil
                storefront = nil
                currentPlayerMMR = nil
                loadout = nil
                collections = nil
                friends = nil
            }

            let walletURL = baseURL
                .appending(path: "wallet")
                .appending(path: loadedPlayer.puuid)
            do {
                wallet = try await fetchJSON(from: walletURL)
            } catch {
                walletErrorMessage = "Player loaded, but wallet failed: \(error.localizedDescription)"
            }

            let storefrontURL = baseURL
                .appending(path: "storefront")
                .appending(path: loadedPlayer.puuid)
            do {
                storefront = try await fetchJSON(from: storefrontURL)
            } catch {
                storefrontErrorMessage = "Player loaded, but shop failed: \(error.localizedDescription)"
            }

            let mmrURL = baseURL
                .appending(path: "mmr")
                .appending(path: loadedPlayer.puuid)
            do {
                currentPlayerMMR = try await fetchJSON(from: mmrURL)
            } catch {
                currentPlayerMMRErrorMessage = error.localizedDescription
            }

            let loadoutURL = baseURL
                .appending(path: "loadout")
                .appending(path: loadedPlayer.puuid)
            do {
                loadout = try await fetchJSON(from: loadoutURL)
            } catch {
                loadoutErrorMessage = "Player loaded, but loadout failed: \(error.localizedDescription)"
            }

            let collectionsURL = baseURL
                .appending(path: "collections")
                .appending(path: loadedPlayer.puuid)
            do {
                collections = try await fetchJSON(from: collectionsURL)
            } catch {
                collectionsErrorMessage = "Player loaded, but collections failed: \(error.localizedDescription)"
            }

            let friendsURL = baseURL.appending(path: "friends")
            do {
                friends = try await fetchJSON(from: friendsURL)
                await loadFavoriteFriendRanks()
                await loadFavoriteFriendStatuses()
            } catch {
                friendsErrorMessage = "Player loaded, but friends failed: \(error.localizedDescription)"
            }

            lastFetchedAt = Date()
            saveCachedSnapshot()
        } catch {
            isServerOnline = false
            errorMessage = "Could not load player data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func toggleFavoriteFriend(_ friend: BridgeFriend) {
        if favoriteFriendIDs.contains(friend.puuid) {
            favoriteFriendIDs.remove(friend.puuid)
            favoriteFriendRanks.removeValue(forKey: friend.puuid)
            favoriteFriendRankErrors.removeValue(forKey: friend.puuid)
            favoriteFriendStatuses.removeValue(forKey: friend.puuid)
        } else {
            favoriteFriendIDs.insert(friend.puuid)
        }

        saveFavoriteFriendIDs()
    }

    func loadFavoriteFriendRanks() async {
        friendsErrorMessage = nil

        guard !favoriteFriendIDs.isEmpty else {
            favoriteFriendRanks = [:]
            favoriteFriendRankErrors = [:]
            favoriteFriendStatuses = [:]
            return
        }

        do {
            let joinedIDs = favoriteFriendIDs.joined(separator: ",")
            var components = URLComponents(
                url: baseURL.appending(path: "friends/mmr"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "puuids", value: joinedIDs)
            ]

            guard let url = components?.url else {
                throw BridgeError.invalidResponse
            }

            let rankedFriends: BridgeFriends = try await fetchJSON(from: url)
            var ranks = favoriteFriendRanks.filter { favoriteFriendIDs.contains($0.key) }
            var errors: [String: String] = [:]

            for friend in rankedFriends.friends {
                if let mmr = friend.mmr {
                    ranks[friend.puuid] = mmr
                }

                if friend.mmrError != nil {
                    errors[friend.puuid] = friend.rankUnavailableText
                }
            }

            favoriteFriendRanks = ranks
            favoriteFriendRankErrors = errors
            saveCachedSnapshot()
        } catch {
            friendsErrorMessage = "Favorite ranks failed: \(error.localizedDescription)"
        }
    }

    func loadFavoriteFriendStatuses() async {
        guard !favoriteFriendIDs.isEmpty else {
            favoriteFriendStatuses = [:]
            return
        }

        do {
            let joinedIDs = favoriteFriendIDs.joined(separator: ",")
            var components = URLComponents(
                url: baseURL.appending(path: "friends/status"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "puuids", value: joinedIDs)
            ]

            guard let url = components?.url else {
                throw BridgeError.invalidResponse
            }

            let statusResponse: BridgeFriendStatusesResponse = try await fetchJSON(from: url)
            var statuses = favoriteFriendStatuses.filter { favoriteFriendIDs.contains($0.key) }

            for status in statusResponse.statuses {
                statuses[status.puuid] = status
            }

            favoriteFriendStatuses = statuses
            saveCachedSnapshot()
        } catch {
            favoriteFriendStatuses = [:]
            saveCachedSnapshot()
        }
    }

    func loadOwnedWeaponSkins(for gun: BridgeLoadoutGun) async throws -> BridgeOwnedWeaponSkins {
        guard let player else {
            throw BridgeError.invalidResponse
        }

        let url = baseURL
            .appending(path: "loadout")
            .appending(path: player.puuid)
            .appending(path: "skins")
            .appending(path: gun.id)

        return try await fetchJSON(from: url)
    }

    func loadOwnedWeaponCharms(for gun: BridgeLoadoutGun) async throws -> BridgeOwnedWeaponCharms {
        guard let player else {
            throw BridgeError.invalidResponse
        }

        let url = baseURL
            .appending(path: "loadout")
            .appending(path: player.puuid)
            .appending(path: "charms")
            .appending(path: gun.id)

        return try await fetchJSON(from: url)
    }

    func equipWeaponSkin(_ skin: BridgeOwnedWeaponSkin, for gun: BridgeLoadoutGun) async throws {
        guard let player else {
            throw BridgeError.invalidResponse
        }

        let url = baseURL
            .appending(path: "loadout")
            .appending(path: player.puuid)
            .appending(path: "equip")
        let body = BridgeEquipWeaponSkinRequest(
            weaponID: gun.id,
            skinID: skin.skinID,
            skinLevelID: skin.skinLevelID,
            chromaID: skin.chromaID
        )
        let updatedLoadout: BridgeLoadout = try await sendJSON(to: url, method: "PUT", body: body)
        loadout = updatedLoadout
        saveCachedSnapshot()
    }

    func equipWeaponCharm(_ charm: BridgeOwnedWeaponCharm, for gun: BridgeLoadoutGun) async throws {
        guard let player else {
            throw BridgeError.invalidResponse
        }

        let url = baseURL
            .appending(path: "loadout")
            .appending(path: player.puuid)
            .appending(path: "equip-charm")
        let body = BridgeEquipWeaponCharmRequest(
            weaponID: gun.id,
            charmID: charm.charmID,
            charmLevelID: charm.charmLevelID
        )
        let updatedLoadout: BridgeLoadout = try await sendJSON(to: url, method: "PUT", body: body)
        loadout = updatedLoadout
        saveCachedSnapshot()
    }

    private func checkHealth() async throws {
        let healthURL = baseURL.appending(path: "health")
        let _: BridgeHealth = try await fetchJSON(from: healthURL, timeout: 2)
        isServerOnline = true
    }

    private func loadCachedSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let snapshot = try? JSONDecoder().decode(BridgeCachedSnapshot.self, from: data) else {
            return
        }

        player = snapshot.player
        wallet = snapshot.wallet
        storefront = snapshot.storefront
        currentPlayerMMR = snapshot.currentPlayerMMR
        loadout = snapshot.loadout
        collections = snapshot.collections
        friends = snapshot.friends
        favoriteFriendRanks = snapshot.favoriteFriendRanks
        favoriteFriendRankErrors = snapshot.favoriteFriendRankErrors
        favoriteFriendStatuses = snapshot.favoriteFriendStatuses
        lastFetchedAt = snapshot.fetchedAt

        if let puuid = snapshot.player?.puuid {
            loadFavoriteFriendIDs(for: puuid)
        }
    }

    private func saveCachedSnapshot() {
        let snapshot = BridgeCachedSnapshot(
            fetchedAt: lastFetchedAt ?? Date(),
            player: player,
            wallet: wallet,
            storefront: storefront,
            currentPlayerMMR: currentPlayerMMR,
            loadout: loadout,
            collections: collections,
            friends: friends,
            favoriteFriendRanks: favoriteFriendRanks,
            favoriteFriendRankErrors: favoriteFriendRankErrors,
            favoriteFriendStatuses: favoriteFriendStatuses
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadFavoriteFriendIDs(for puuid: String) {
        let savedIDs = UserDefaults.standard.stringArray(forKey: favoriteFriendIDsKey(for: puuid)) ?? []
        favoriteFriendIDs = Set(savedIDs)
    }

    private func saveFavoriteFriendIDs() {
        guard let player else {
            return
        }

        UserDefaults.standard.set(Array(favoriteFriendIDs), forKey: favoriteFriendIDsKey(for: player.puuid))
    }

    private func favoriteFriendIDsKey(for puuid: String) -> String {
        "\(favoriteFriendIDsKeyPrefix).\(puuid)"
    }

    private func fetchJSON<T: Decodable>(from url: URL, timeout: TimeInterval = 15) async throws -> T {
        let request = URLRequest(url: url, timeoutInterval: timeout)
        return try await perform(request)
    }

    private func sendJSON<Body: Encodable, Response: Decodable>(
        to url: URL,
        method: String,
        body: Body,
        timeout: TimeInterval = 20
    ) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8)
            throw BridgeError.badStatus(httpResponse.statusCode, request.url ?? URL(string: "about:blank")!, responseBody)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct BridgeHealth: Decodable {
    let ok: Bool
}

struct BridgeCachedSnapshot: Codable {
    let fetchedAt: Date
    let player: BridgePlayer?
    let wallet: BridgeWallet?
    let storefront: BridgeStorefront?
    let currentPlayerMMR: BridgeFriendMMR?
    let loadout: BridgeLoadout?
    let collections: BridgeCollections?
    let friends: BridgeFriends?
    let favoriteFriendRanks: [String: BridgeFriendMMR]
    let favoriteFriendRankErrors: [String: String]
    let favoriteFriendStatuses: [String: BridgeFriendStatus]
}

struct BridgePlayer: Codable {
    let gameName: String
    let tagLine: String
    let puuid: String
    let level: Int
}

struct BridgeWallet: Codable {
    let balances: [String: Int]

    private enum CodingKeys: String, CodingKey {
        case balances = "Balances"
    }

    var items: [BridgeWalletItem] {
        balances
            .compactMap { id, amount in
                guard let name = BridgeWallet.currencyName(for: id) else {
                    return nil
                }

                return BridgeWalletItem(id: id, name: name, amount: amount)
            }
            .sorted { $0.name < $1.name }
    }

    var orderedItems: [BridgeWalletItem] {
        BridgeWalletItem.currencyOrder.map { currency in
            let amount = balances[currency.id] ?? balances[currency.id.uppercased()] ?? 0
            return BridgeWalletItem(currency: currency, amount: amount)
        }
    }

    private static func currencyName(for id: String) -> String? {
        switch id.lowercased() {
        case "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741":
            "Valorant Points"
        case "e59aa87c-4cbf-517a-5983-6e81511be9b7":
            "Radianite"
        case "85ca954a-41f2-ce94-9b45-8ca3dd39a00d":
            "Kingdom Credits"
        default:
            nil
        }
    }
}

struct BridgeWalletItem: Identifiable {
    let id: String
    let name: String
    let amount: Int

    var shortName: String {
        switch id.lowercased() {
        case Self.valorantPointsID:
            return "VP"
        case Self.radianiteID:
            return "Radianite"
        case Self.kingdomCreditsID:
            return "Kingdom"
        default:
            return name
        }
    }

    var iconURL: URL? {
        URL(string: "https://media.valorant-api.com/currencies/\(id.lowercased())/displayicon.png")
    }

    var fallbackSystemImage: String {
        switch id.lowercased() {
        case Self.valorantPointsID:
            return "v.circle.fill"
        case Self.radianiteID:
            return "r.circle.fill"
        case Self.kingdomCreditsID:
            return "k.circle.fill"
        default:
            return "circle.fill"
        }
    }

    init(id: String, name: String, amount: Int) {
        self.id = id
        self.name = name
        self.amount = amount
    }

    init(currency: BridgeWalletCurrency, amount: Int) {
        self.id = currency.id
        self.name = currency.name
        self.amount = amount
    }

    static let valorantPointsID = "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
    static let radianiteID = "e59aa87c-4cbf-517a-5983-6e81511be9b7"
    static let kingdomCreditsID = "85ca954a-41f2-ce94-9b45-8ca3dd39a00d"

    static let currencyOrder = [
        BridgeWalletCurrency(id: valorantPointsID, name: "Valorant Points"),
        BridgeWalletCurrency(id: radianiteID, name: "Radianite"),
        BridgeWalletCurrency(id: kingdomCreditsID, name: "Kingdom Credits")
    ]

    static func orderedCurrencyPlaceholders(wallet: BridgeWallet?) -> [BridgeWalletItem] {
        guard let wallet else {
            return currencyOrder.map { BridgeWalletItem(currency: $0, amount: 0) }
        }

        return wallet.orderedItems
    }
}

struct BridgeWalletCurrency {
    let id: String
    let name: String
}

struct BridgeStorefront: Codable {
    let offers: [BridgeStorefrontOffer]
    let durationRemainingInSeconds: Int

    var remainingTimeText: String {
        let hours = durationRemainingInSeconds / 3600
        let minutes = (durationRemainingInSeconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct BridgeStorefrontOffer: Codable, Identifiable {
    let offerID: String
    let itemID: String
    let name: String
    let iconURL: URL?
    let price: Int
    let currencyID: String
    let contentTierUUID: String?
    let contentTierName: String?
    let contentTierColor: String?
    let contentTierIconURL: URL?

    var id: String {
        offerID
    }

    var contentTierColorValue: Color? {
        guard let contentTierColor else {
            return nil
        }

        return Color(hex: contentTierColor)
    }
}

struct BridgeCollections: Codable {
    let sprays: [BridgeCollectionItem]
    let playerCards: [BridgeCollectionItem]
}

struct BridgeCollectionItem: Codable, Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
}

struct BridgeLoadout: Codable {
    let subject: String
    let guns: [BridgeLoadoutGun]
    let identity: BridgeLoadoutIdentity?

    func gun(named name: String) -> BridgeLoadoutGun? {
        guns.first { $0.matchesWeaponName(name) }
    }

    func guns(named names: [String]) -> [BridgeLoadoutGun] {
        names.compactMap { gun(named: $0) }
    }

    var sections: [BridgeLoadoutSection] {
        let orderedSections: [(String, (BridgeLoadoutGun) -> Bool)] = [
            ("Main", { $0.isMainWeapon }),
            ("Snipers", { $0.categoryKey.contains("sniper") }),
            ("Rifles", { $0.categoryKey.contains("rifle") && !$0.isMainWeapon }),
            ("SMGs", { $0.categoryKey.contains("smg") }),
            ("Sidearms", { $0.categoryKey.contains("sidearm") && !$0.isMainWeapon }),
            ("Heavy", { $0.categoryKey.contains("heavy") }),
            ("Shotguns", { $0.categoryKey.contains("shotgun") })
        ]

        var usedIDs = Set<String>()
        var sections = orderedSections.compactMap { title, matches -> BridgeLoadoutSection? in
            let sectionGuns = guns
                .filter { gun in
                    matches(gun) && !usedIDs.contains(gun.id)
                }
                .sorted { $0.sortName < $1.sortName }

            guard !sectionGuns.isEmpty else {
                return nil
            }

            usedIDs.formUnion(sectionGuns.map(\.id))
            return BridgeLoadoutSection(title: title, guns: sectionGuns)
        }

        let otherGuns = guns
            .filter { !usedIDs.contains($0.id) }
            .sorted { $0.sortName < $1.sortName }

        if !otherGuns.isEmpty {
            sections.append(BridgeLoadoutSection(title: "Other", guns: otherGuns))
        }

        return sections
    }
}

struct BridgeLoadoutGun: Codable, Identifiable {
    let id: String
    let weaponName: String
    let skinName: String
    let displayName: String
    let iconURL: URL?
    let category: String
    let skinID: String
    let skinLevelID: String
    let chromaID: String
    let charmID: String?
    let charmLevelID: String?
    let charmName: String?
    let charmIconURL: URL?
    let contentTierUUID: String?
    let contentTierName: String?
    let contentTierColor: String?
    let contentTierIconURL: URL?

    var categoryKey: String {
        category.lowercased()
    }

    var contentTierColorValue: Color? {
        guard let contentTierColor else {
            return nil
        }

        return Color(hex: contentTierColor)
    }

    var sortName: String {
        displayWeaponName.lowercased()
    }

    var displayWeaponName: String {
        if categoryKey.contains("melee") || weaponName.localizedCaseInsensitiveContains("melee") {
            return "Melee"
        }

        return Self.cleanLoadoutName(weaponName)
    }

    var displaySkinName: String {
        let cleanedName = Self.cleanLoadoutName(skinName)

        if displayWeaponName == "Melee", cleanedName.localizedCaseInsensitiveContains("melee") {
            let withoutWeapon = cleanedName
                .replacingOccurrences(of: "Melee", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return withoutWeapon.isEmpty ? "Melee" : withoutWeapon
        }

        return cleanedName
    }

    var isMainWeapon: Bool {
        let weapon = displayWeaponName.lowercased()
        return weapon == "vandal" || weapon == "phantom" || weapon == "melee"
    }

    func matchesWeaponName(_ name: String) -> Bool {
        displayWeaponName.lowercased() == name.lowercased()
    }

    private static func cleanLoadoutName(_ name: String) -> String {
        var cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let levelRange = cleanedName.range(
            of: #"\s+Level\s+\d+.*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            cleanedName.removeSubrange(levelRange)
        }

        if let levelRange = cleanedName.range(
            of: #"\s+Lv\.?\s*\d+.*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            cleanedName.removeSubrange(levelRange)
        }

        return cleanedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct BridgeOwnedWeaponSkins: Codable {
    let weaponID: String
    let weaponName: String
    let equippedSkinID: String
    let skins: [BridgeOwnedWeaponSkin]
}

struct BridgeOwnedWeaponCharms: Codable {
    let weaponID: String
    let weaponName: String
    let equippedCharmID: String
    let charms: [BridgeOwnedWeaponCharm]
}

struct BridgeOwnedWeaponSkin: Codable, Identifiable {
    let id: String
    let weaponID: String
    let name: String
    let iconURL: URL?
    let skinID: String
    let skinLevelID: String
    let chromaID: String
    let isEquipped: Bool
}

struct BridgeOwnedWeaponCharm: Codable, Identifiable {
    let id: String
    let weaponID: String
    let name: String
    let iconURL: URL?
    let charmID: String
    let charmLevelID: String
    let isEquipped: Bool
}

struct BridgeEquipWeaponSkinRequest: Encodable {
    let weaponID: String
    let skinID: String
    let skinLevelID: String
    let chromaID: String
}

struct BridgeEquipWeaponCharmRequest: Encodable {
    let weaponID: String
    let charmID: String
    let charmLevelID: String
}

struct BridgeLoadoutIdentity: Codable {
    let playerCardID: String?
    let playerTitleID: String?
    let accountLevel: Int
    let preferredLevelBorderID: String?
    let hideAccountLevel: Bool
}

struct BridgeLoadoutSection: Identifiable {
    let title: String
    let guns: [BridgeLoadoutGun]

    var id: String {
        title
    }

    var isMain: Bool {
        title == "Main"
    }
}

struct BridgeFriends: Codable {
    let friends: [BridgeFriend]
}

struct BridgeFriend: Codable, Identifiable {
    let puuid: String
    let gameName: String
    let tagLine: String
    var mmr: BridgeFriendMMR?
    var mmrError: String?
    var mmrErrorStatus: Int?
    var status: BridgeFriendStatus?

    var id: String {
        puuid
    }

    var rankUnavailableText: String {
        if let mmrErrorStatus {
            return "Rank unavailable (HTTP \(mmrErrorStatus))"
        }

        return "Rank unavailable"
    }
}

struct BridgeFriendStatusesResponse: Decodable {
    let statuses: [BridgeFriendStatus]
}

struct BridgeFriendStatus: Codable {
    let puuid: String
    let isOnline: Bool
    let availability: String
    let state: String?
    let product: String
}

struct BridgeFriendMMR: Codable {
    let subject: String?
    let competitiveTier: Int
    let rankedRating: Int
    let leaderboardRank: Int
    let numberOfWins: Int
    let seasonID: String?
    let hasRank: Bool
    let rankName: String
    let rankIconURL: URL?
    let lastMatchID: String?
    let lastMatchStartTime: Int?
    let lastMatchRRChange: Int?
    let lastMatchRRPerformanceBonus: Int
    let lastMatchAFKPenalty: Int
    let lastMatchRankedRatingBefore: Int?
    let lastMatchRankedRatingAfter: Int?
    let lastMatchTierBefore: Int?
    let lastMatchTierAfter: Int?
    let lastMatchRRChanges: [BridgeRRChange]
    let lastMatchRRChangesError: String?
    let actRankWins: [BridgeActRankWin]
    let actRankBadgeCells: [BridgeActRankBadgeCell]
    let actRankBadgeHidden: Bool
    let acts: [BridgeActRankAct]

    var lastMatchRRChangeText: String {
        guard let lastMatchRRChange else {
            return "Last match RR unavailable"
        }

        let sign = lastMatchRRChange >= 0 ? "+" : ""
        var text = "\(sign)\(lastMatchRRChange) RR last match"

        if lastMatchRRPerformanceBonus > 0 {
            text += " (+\(lastMatchRRPerformanceBonus) bonus)"
        }

        if lastMatchAFKPenalty > 0 {
            text += " (-\(lastMatchAFKPenalty) AFK)"
        }

        return text
    }

    private enum CodingKeys: String, CodingKey {
        case subject
        case competitiveTier
        case rankedRating
        case leaderboardRank
        case numberOfWins
        case seasonID
        case hasRank
        case rankName
        case rankIconURL
        case lastMatchID
        case lastMatchStartTime
        case lastMatchRRChange
        case lastMatchRRPerformanceBonus
        case lastMatchAFKPenalty
        case lastMatchRankedRatingBefore
        case lastMatchRankedRatingAfter
        case lastMatchTierBefore
        case lastMatchTierAfter
        case lastMatchRRChanges
        case lastMatchRRChangesError
        case actRankWins
        case actRankBadgeCells
        case actRankBadgeHidden
        case acts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        competitiveTier = try container.decodeIfPresent(Int.self, forKey: .competitiveTier) ?? 0
        rankedRating = try container.decodeIfPresent(Int.self, forKey: .rankedRating) ?? 0
        leaderboardRank = try container.decodeIfPresent(Int.self, forKey: .leaderboardRank) ?? 0
        numberOfWins = try container.decodeIfPresent(Int.self, forKey: .numberOfWins) ?? 0
        seasonID = try container.decodeIfPresent(String.self, forKey: .seasonID)
        hasRank = (try container.decodeIfPresent(Bool.self, forKey: .hasRank)) ?? (competitiveTier > 0)
        rankName = try container.decodeIfPresent(String.self, forKey: .rankName) ?? (competitiveTier > 0 ? "Tier \(competitiveTier)" : "Unrated")
        rankIconURL = try container.decodeIfPresent(URL.self, forKey: .rankIconURL)
        lastMatchID = try container.decodeIfPresent(String.self, forKey: .lastMatchID)
        lastMatchStartTime = try container.decodeIfPresent(Int.self, forKey: .lastMatchStartTime)
        lastMatchRRChange = try container.decodeIfPresent(Int.self, forKey: .lastMatchRRChange)
        lastMatchRRPerformanceBonus = try container.decodeIfPresent(Int.self, forKey: .lastMatchRRPerformanceBonus) ?? 0
        lastMatchAFKPenalty = try container.decodeIfPresent(Int.self, forKey: .lastMatchAFKPenalty) ?? 0
        lastMatchRankedRatingBefore = try container.decodeIfPresent(Int.self, forKey: .lastMatchRankedRatingBefore)
        lastMatchRankedRatingAfter = try container.decodeIfPresent(Int.self, forKey: .lastMatchRankedRatingAfter)
        lastMatchTierBefore = try container.decodeIfPresent(Int.self, forKey: .lastMatchTierBefore)
        lastMatchTierAfter = try container.decodeIfPresent(Int.self, forKey: .lastMatchTierAfter)
        lastMatchRRChanges = try container.decodeIfPresent([BridgeRRChange].self, forKey: .lastMatchRRChanges) ?? []
        lastMatchRRChangesError = try container.decodeIfPresent(String.self, forKey: .lastMatchRRChangesError)
        actRankWins = try container.decodeIfPresent([BridgeActRankWin].self, forKey: .actRankWins) ?? []
        actRankBadgeCells = try container.decodeIfPresent([BridgeActRankBadgeCell].self, forKey: .actRankBadgeCells) ?? []
        actRankBadgeHidden = try container.decodeIfPresent(Bool.self, forKey: .actRankBadgeHidden) ?? false
        acts = try container.decodeIfPresent([BridgeActRankAct].self, forKey: .acts) ?? []
    }

    var currentActFallback: BridgeActRankAct {
        BridgeActRankAct(
            seasonID: seasonID ?? "current",
            name: "Current Act",
            type: "act",
            startTime: "",
            endTime: "",
            isCurrent: true,
            competitiveTier: competitiveTier,
            rankedRating: rankedRating,
            leaderboardRank: leaderboardRank,
            numberOfWins: numberOfWins,
            winsByTier: actRankWins,
            badgeCells: actRankBadgeCells
        )
    }
}

struct BridgeActRankWin: Codable, Identifiable {
    let tier: Int
    let wins: Int

    var id: Int {
        tier
    }

    var rankName: String {
        CompetitiveTierName.name(for: tier)
    }

    var color: Color {
        CompetitiveTierColor.color(for: tier)
    }
}

struct BridgeActRankAct: Codable, Identifiable {
    let seasonID: String
    let name: String
    let type: String
    let startTime: String
    let endTime: String
    let isCurrent: Bool
    let competitiveTier: Int
    let rankedRating: Int
    let leaderboardRank: Int
    let numberOfWins: Int
    let winsByTier: [BridgeActRankWin]
    let badgeCells: [BridgeActRankBadgeCell]

    var id: String {
        seasonID
    }
}

struct BridgeActRankBadgeCell: Codable {
    let tier: Int
    let rankTriangleDownIconURL: URL?
    let rankTriangleUpIconURL: URL?

    var color: Color {
        CompetitiveTierColor.color(for: tier)
    }
}

enum CompetitiveTierColor {
    static func color(for tier: Int) -> Color {
        switch tier {
        case 3...5:
            return Color(red: 0.55, green: 0.58, blue: 0.62)
        case 6...8:
            return Color(red: 0.74, green: 0.43, blue: 0.26)
        case 9...11:
            return Color(red: 0.72, green: 0.78, blue: 0.82)
        case 12...14:
            return Color(red: 0.95, green: 0.72, blue: 0.22)
        case 15...17:
            return Color(red: 0.20, green: 0.82, blue: 0.78)
        case 18...20:
            return Color(red: 0.64, green: 0.43, blue: 0.96)
        case 21...23:
            return Color(red: 0.35, green: 0.86, blue: 0.48)
        case 24...26:
            return Color(red: 0.86, green: 0.20, blue: 0.32)
        case 27:
            return Color(red: 1.0, green: 0.86, blue: 0.35)
        default:
            return .secondary
        }
    }
}

struct BridgeRRChange: Codable, Identifiable {
    let matchID: String?
    let matchStartTime: Int?
    let rrChange: Int?
    let rrPerformanceBonus: Int
    let afkPenalty: Int
    let rankedRatingBefore: Int?
    let rankedRatingAfter: Int?
    let tierBefore: Int?
    let tierAfter: Int?
    let seasonID: String?
    let mapID: String?

    var id: String {
        matchID ?? "\(matchStartTime ?? 0)-\(rrChange ?? 0)-\(rankedRatingAfter ?? 0)"
    }

    var displayText: String {
        guard let rrChange else {
            return "RR change unavailable"
        }

        let sign = rrChange >= 0 ? "+" : ""
        var text = "\(sign)\(rrChange) RR"

        if let rankedRatingBefore, let rankedRatingAfter {
            text += " (\(rankedRatingBefore) -> \(rankedRatingAfter))"
        }

        if rrPerformanceBonus > 0 {
            text += " +\(rrPerformanceBonus) bonus"
        }

        if afkPenalty > 0 {
            text += " -\(afkPenalty) AFK"
        }

        return text
    }

    var compactDisplayText: String {
        guard let rrChange else {
            return "--"
        }

        let sign = rrChange >= 0 ? "+" : ""
        var text = "\(sign)\(rrChange)"

        if rrPerformanceBonus > 0 {
            text += " B\(rrPerformanceBonus)"
        }

        if afkPenalty > 0 {
            text += " A\(afkPenalty)"
        }

        return text
    }

    var tint: Color {
        guard let rrChange else {
            return .orange
        }

        if rrChange > 0 {
            return .green
        }

        if rrChange < 0 {
            return .red
        }

        return .secondary
    }
}

enum CompetitiveTierName {
    static func name(for tier: Int) -> String {
        switch tier {
        case 3:
            return "Iron 1"
        case 4:
            return "Iron 2"
        case 5:
            return "Iron 3"
        case 6:
            return "Bronze 1"
        case 7:
            return "Bronze 2"
        case 8:
            return "Bronze 3"
        case 9:
            return "Silver 1"
        case 10:
            return "Silver 2"
        case 11:
            return "Silver 3"
        case 12:
            return "Gold 1"
        case 13:
            return "Gold 2"
        case 14:
            return "Gold 3"
        case 15:
            return "Platinum 1"
        case 16:
            return "Platinum 2"
        case 17:
            return "Platinum 3"
        case 18:
            return "Diamond 1"
        case 19:
            return "Diamond 2"
        case 20:
            return "Diamond 3"
        case 21:
            return "Ascendant 1"
        case 22:
            return "Ascendant 2"
        case 23:
            return "Ascendant 3"
        case 24:
            return "Immortal 1"
        case 25:
            return "Immortal 2"
        case 26:
            return "Immortal 3"
        case 27:
            return "Radiant"
        default:
            return "Tier \(tier)"
        }
    }
}

extension Color {
    init?(hex: String) {
        let trimmedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let value = UInt64(trimmedHex, radix: 16) else {
            return nil
        }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch trimmedHex.count {
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        case 8:
            red = Double((value & 0xFF000000) >> 24) / 255
            green = Double((value & 0x00FF0000) >> 16) / 255
            blue = Double((value & 0x0000FF00) >> 8) / 255
            alpha = 1
        default:
            return nil
        }

        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum BridgeError: LocalizedError {
    case invalidResponse
    case badStatus(Int, URL, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The PC bridge returned an invalid response."
        case .badStatus(let statusCode, let url, let responseBody):
            if let responseBody, !responseBody.isEmpty {
                "HTTP \(statusCode) from \(url.path): \(responseBody)"
            } else {
                "HTTP \(statusCode) from \(url.path)."
            }
        }
    }
}

/*
 Previous RSO login prototype. Keeping this commented out for later.

 import AuthenticationServices
 import Combine
 import UIKit

 @MainActor
 final class RiotSignInController: NSObject, ObservableObject {
     @Published var authorizationCode: String?
     @Published var errorMessage: String?
     @Published var isSigningIn = false

     private let clientID = "YOUR_RIOT_CLIENT_ID"
     private let redirectURI = "rrstalker://callback"
     private var session: ASWebAuthenticationSession?

     func start() {
         guard clientID != "YOUR_RIOT_CLIENT_ID" else {
             errorMessage = "Add your Riot RSO client ID before signing in."
             return
         }

         guard let authURL = makeAuthorizationURL() else {
             errorMessage = "Could not build the Riot sign-in URL."
             return
         }

         authorizationCode = nil
         errorMessage = nil
         isSigningIn = true

         let session = ASWebAuthenticationSession(
             url: authURL,
             callbackURLScheme: "rrstalker"
         ) { [weak self] callbackURL, error in
             Task { @MainActor in
                 self?.handleCallback(callbackURL, error: error)
             }
         }

         session.presentationContextProvider = self
         session.prefersEphemeralWebBrowserSession = true
         self.session = session
         session.start()
     }

     private func makeAuthorizationURL() -> URL? {
         var components = URLComponents(string: "https://auth.riotgames.com/authorize")
         components?.queryItems = [
             URLQueryItem(name: "client_id", value: clientID),
             URLQueryItem(name: "redirect_uri", value: redirectURI),
             URLQueryItem(name: "response_type", value: "code"),
             URLQueryItem(name: "scope", value: "openid offline_access")
         ]

         return components?.url
     }

     private func handleCallback(_ callbackURL: URL?, error: Error?) {
         isSigningIn = false
         session = nil

         if let error {
             errorMessage = error.localizedDescription
             return
         }

         guard let callbackURL,
               let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
             errorMessage = "Riot did not return an authorization code."
             return
         }

         authorizationCode = code
     }
 }

 extension RiotSignInController: ASWebAuthenticationPresentationContextProviding {
     func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
         UIApplication.shared.connectedScenes
             .compactMap { $0 as? UIWindowScene }
             .flatMap(\.windows)
             .first { $0.isKeyWindow } ?? ASPresentationAnchor(frame: .zero)
     }
 }
*/

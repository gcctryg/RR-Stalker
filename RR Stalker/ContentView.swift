//
//  ContentView.swift
//  RR Stalker
//
//  Created by Xuelu Feng on 5/18/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var bridge = PCBridgeClient()

    var body: some View {
        TabView {
            LoadoutView(bridge: bridge)
                .tabItem {
                    Label("Loadout", systemImage: "scope")
                }

            FriendListView(bridge: bridge)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }

            ProfileView(bridge: bridge)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .task {
            await bridge.loadPlayer()
        }
    }
}

struct LoadoutView: View {
    @ObservedObject var bridge: PCBridgeClient

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderBanner(bridge: bridge)

                Text("Loadout")
                    .font(.largeTitle.bold())

                if let loadout = bridge.loadout, !loadout.guns.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(loadout.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(section.isMain ? .title3.bold() : .headline)

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(section.guns) { gun in
                                        LoadoutWeaponCard(gun: gun)
                                    }
                                }
                            }
                        }
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
    }
}

struct ProfileView: View {
    @ObservedObject var bridge: PCBridgeClient

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBanner(bridge: bridge)

                if let player = bridge.player {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Player")
                            .font(.headline)

                        InfoRow(title: "Name", value: "\(player.gameName)#\(player.tagLine)")
                        InfoRow(title: "Level", value: "\(player.level)")
                        InfoRow(title: "PUUID", value: player.puuid)

                        if let wallet = bridge.wallet {
                            Divider()
                            Text("Wallet")
                                .font(.headline)

                            ForEach(wallet.items) { item in
                                InfoRow(title: item.name, value: "\(item.amount)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                if let storefront = bridge.storefront {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Shop")
                                .font(.headline)
                            Spacer()
                            Text(storefront.remainingTimeText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ForEach(storefront.offers) { offer in
                            ShopOfferRow(offer: offer)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

struct FriendListView: View {
    @ObservedObject var bridge: PCBridgeClient
    @State private var isSelectingFavorites = false

    var body: some View {
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
                            FriendRow(friend: friend)
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
                            await bridge.loadFavoriteFriendCards()
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
    private var hasCardBackground: Bool {
        friend.playerCard?.backgroundURL != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            RankIconView(mmr: friend.mmr)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(friend.gameName)#\(friend.tagLine)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(primaryTextStyle)

                if let mmr = friend.mmr {
                    Text(mmr.rankName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryTextStyle)
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
                    .foregroundStyle(secondaryTextStyle)
                } else if friend.mmr != nil {
                    Text("Unrated")
                        .font(.caption)
                        .foregroundStyle(secondaryTextStyle)
                } else if friend.mmrError != nil {
                    Text(friend.rankUnavailableText)
                        .font(.caption)
                        .foregroundStyle(secondaryTextStyle)
                }

                Text(friend.puuid)
                    .font(.caption2.monospaced())
                    .foregroundStyle(tertiaryTextStyle)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            FriendCardBackground(card: friend.playerCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: hasCardBackground ? .black.opacity(0.18) : .clear, radius: 1, x: 0, y: 1)
    }

    private var primaryTextStyle: Color {
        hasCardBackground ? .white : .primary
    }

    private var secondaryTextStyle: Color {
        hasCardBackground ? .white.opacity(0.9) : .secondary
    }

    private var tertiaryTextStyle: Color {
        hasCardBackground ? .white.opacity(0.72) : .tertiary
    }
}

struct FriendCardBackground: View {
    let card: BridgeFriendCard?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.thinMaterial)

            if let cardURL = card?.backgroundURL {
                AsyncImage(url: cardURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        .black.opacity(0.72),
                                        .black.opacity(0.48),
                                        .black.opacity(0.68)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    default:
                        Color.clear
                    }
                }
            }
        }
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
    var body: some View {
        NavigationStack {
            List {
                Section("Bridge") {
                    Text("Update the PC bridge URL in ContentView.swift when your PC IP changes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
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

                Text(bridge.baseURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
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
            SettingsView()
        }
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

struct ShopOfferRow: View {
    let offer: BridgeStorefrontOffer

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: offer.iconURL) { phase in
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

            VStack(alignment: .leading, spacing: 6) {
                Text(offer.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text("\(offer.price) VP")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LoadoutWeaponCard: View {
    let gun: BridgeLoadoutGun

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            .frame(height: 96)

            VStack(alignment: .leading, spacing: 4) {
                Text(gun.weaponName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(gun.skinName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(gun.category)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
final class PCBridgeClient: ObservableObject {
    private let favoriteFriendIDsKeyPrefix = "favoriteFriendIDs"

    @Published var player: BridgePlayer?
    @Published var wallet: BridgeWallet?
    @Published var storefront: BridgeStorefront?
    @Published var loadout: BridgeLoadout?
    @Published var friends: BridgeFriends?
    @Published var favoriteFriendIDs: Set<String>
    @Published var favoriteFriendRanks: [String: BridgeFriendMMR] = [:]
    @Published var favoriteFriendRankErrors: [String: String] = [:]
    @Published var favoriteFriendCards: [String: BridgeFriendCard] = [:]
    @Published var errorMessage: String?
    @Published var walletErrorMessage: String?
    @Published var storefrontErrorMessage: String?
    @Published var loadoutErrorMessage: String?
    @Published var friendsErrorMessage: String?
    @Published var isLoading = false

    // Replace this with your PC's local IP address.
    let baseURL = URL(string: "http://192.168.0.14:3000")!

    init() {
        favoriteFriendIDs = []
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
                favorite.playerCard = favoriteFriendCards[friend.puuid]
                return favorite
            }
    }

    func loadPlayer() async {
        isLoading = true
        errorMessage = nil
        walletErrorMessage = nil
        storefrontErrorMessage = nil
        loadoutErrorMessage = nil
        friendsErrorMessage = nil

        do {
            let url = baseURL.appending(path: "player")
            let loadedPlayer: BridgePlayer = try await fetchJSON(from: url)
            let previousPlayerPUUID = player?.puuid
            player = loadedPlayer
            loadFavoriteFriendIDs(for: loadedPlayer.puuid)
            if previousPlayerPUUID != loadedPlayer.puuid {
                favoriteFriendRanks = [:]
                favoriteFriendRankErrors = [:]
                favoriteFriendCards = [:]
            }

            let walletURL = baseURL
                .appending(path: "wallet")
                .appending(path: loadedPlayer.puuid)
            do {
                wallet = try await fetchJSON(from: walletURL)
            } catch {
                wallet = nil
                walletErrorMessage = "Player loaded, but wallet failed: \(error.localizedDescription)"
            }

            let storefrontURL = baseURL
                .appending(path: "storefront")
                .appending(path: loadedPlayer.puuid)
            do {
                storefront = try await fetchJSON(from: storefrontURL)
            } catch {
                storefront = nil
                storefrontErrorMessage = "Player loaded, but shop failed: \(error.localizedDescription)"
            }

            let loadoutURL = baseURL
                .appending(path: "loadout")
                .appending(path: loadedPlayer.puuid)
            do {
                loadout = try await fetchJSON(from: loadoutURL)
            } catch {
                loadout = nil
                loadoutErrorMessage = "Player loaded, but loadout failed: \(error.localizedDescription)"
            }

            let friendsURL = baseURL.appending(path: "friends")
            do {
                friends = try await fetchJSON(from: friendsURL)
                await loadFavoriteFriendRanks()
                await loadFavoriteFriendCards()
            } catch {
                friends = nil
                friendsErrorMessage = "Player loaded, but friends failed: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Could not load player data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func toggleFavoriteFriend(_ friend: BridgeFriend) {
        if favoriteFriendIDs.contains(friend.puuid) {
            favoriteFriendIDs.remove(friend.puuid)
            favoriteFriendRanks.removeValue(forKey: friend.puuid)
            favoriteFriendRankErrors.removeValue(forKey: friend.puuid)
            favoriteFriendCards.removeValue(forKey: friend.puuid)
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
            favoriteFriendCards = [:]
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
        } catch {
            friendsErrorMessage = "Favorite ranks failed: \(error.localizedDescription)"
        }
    }

    func loadFavoriteFriendCards() async {
        guard !favoriteFriendIDs.isEmpty else {
            favoriteFriendCards = [:]
            return
        }

        do {
            let joinedIDs = favoriteFriendIDs.joined(separator: ",")
            var components = URLComponents(
                url: baseURL.appending(path: "friends/cards"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "puuids", value: joinedIDs)
            ]

            guard let url = components?.url else {
                throw BridgeError.invalidResponse
            }

            let cardResponse: BridgeFriendCardsResponse = try await fetchJSON(from: url)
            var cards = favoriteFriendCards.filter { favoriteFriendIDs.contains($0.key) }

            for card in cardResponse.cards {
                cards[card.puuid] = card
            }

            favoriteFriendCards = cards
        } catch {
            // Friend cards are decorative, so keep the last good cards and avoid noisy UI errors.
        }
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

    private func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8)
            throw BridgeError.badStatus(httpResponse.statusCode, url, responseBody)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct BridgePlayer: Decodable {
    let gameName: String
    let tagLine: String
    let puuid: String
    let level: Int
}

struct BridgeWallet: Decodable {
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
}

struct BridgeStorefront: Decodable {
    let offers: [BridgeStorefrontOffer]
    let durationRemainingInSeconds: Int

    var remainingTimeText: String {
        let hours = durationRemainingInSeconds / 3600
        let minutes = (durationRemainingInSeconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct BridgeStorefrontOffer: Decodable, Identifiable {
    let offerID: String
    let itemID: String
    let name: String
    let iconURL: URL?
    let price: Int
    let currencyID: String

    var id: String {
        offerID
    }
}

struct BridgeLoadout: Decodable {
    let subject: String
    let guns: [BridgeLoadoutGun]
    let identity: BridgeLoadoutIdentity?

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

struct BridgeLoadoutGun: Decodable, Identifiable {
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

    var categoryKey: String {
        category.lowercased()
    }

    var sortName: String {
        weaponName.lowercased()
    }

    var isMainWeapon: Bool {
        let weapon = weaponName.lowercased()
        return weapon == "vandal" || weapon == "phantom" || weapon == "melee" || weapon == "sheriff"
    }
}

struct BridgeLoadoutIdentity: Decodable {
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

struct BridgeFriends: Decodable {
    let friends: [BridgeFriend]
}

struct BridgeFriend: Decodable, Identifiable {
    let puuid: String
    let gameName: String
    let tagLine: String
    var mmr: BridgeFriendMMR?
    var mmrError: String?
    var mmrErrorStatus: Int?
    var playerCard: BridgeFriendCard?

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

struct BridgeFriendCardsResponse: Decodable {
    let cards: [BridgeFriendCard]
    let missing: [BridgeFriendCardMissing]?
}

struct BridgeFriendCard: Decodable {
    let puuid: String
    let playerCardID: String
    let displayName: String
    let displayIcon: URL?
    let smallArt: URL?
    let wideArt: URL?
    let largeArt: URL?

    var backgroundURL: URL? {
        wideArt ?? largeArt ?? smallArt ?? displayIcon
    }
}

struct BridgeFriendCardMissing: Decodable {
    let puuid: String
    let reason: String
}

struct BridgeFriendMMR: Decodable {
    let subject: String?
    let competitiveTier: Int
    let rankedRating: Int
    let leaderboardRank: Int
    let numberOfWins: Int
    let seasonID: String?
    let hasRank: Bool
    let rankName: String
    let rankIconURL: URL?

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

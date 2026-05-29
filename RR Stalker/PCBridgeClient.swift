import SwiftUI
import Combine
import Foundation

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

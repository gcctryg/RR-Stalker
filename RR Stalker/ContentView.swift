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
            CurrentPlayerView(bridge: bridge)
                .tabItem {
                    Label("Current Player", systemImage: "person.crop.circle")
                }

            FriendListView(bridge: bridge)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

struct CurrentPlayerView: View {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Friends")
                    .font(.largeTitle.bold())

                if let friends = bridge.friends {
                    if friends.friends.isEmpty {
                        ContentUnavailableView(
                            "No Friends Loaded",
                            systemImage: "person.2.slash",
                            description: Text("Refresh the current player data to load your friend list.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(friends.friends) { friend in
                                FriendRow(friend: friend)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Friend List Empty",
                        systemImage: "person.2",
                        description: Text("Use the refresh button on Current Player to load friend data.")
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
    }
}

struct FriendRow: View {
    let friend: BridgeFriend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(friend.gameName)#\(friend.tagLine)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                if let mmr = friend.mmr {
                    Text(mmr.rankText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
                Text("Rank unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SettingsView: View {
    var body: some View {
        Text("")
    }
}

struct HeaderBanner: View {
    @ObservedObject var bridge: PCBridgeClient

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

@MainActor
final class PCBridgeClient: ObservableObject {
    @Published var player: BridgePlayer?
    @Published var wallet: BridgeWallet?
    @Published var storefront: BridgeStorefront?
    @Published var friends: BridgeFriends?
    @Published var errorMessage: String?
    @Published var walletErrorMessage: String?
    @Published var storefrontErrorMessage: String?
    @Published var friendsErrorMessage: String?
    @Published var isLoading = false

    // Replace this with your PC's local IP address.
    let baseURL = URL(string: "http://192.168.0.14:3000")!

    func loadPlayer() async {
        isLoading = true
        errorMessage = nil
        walletErrorMessage = nil
        storefrontErrorMessage = nil
        friendsErrorMessage = nil

        do {
            let url = baseURL.appending(path: "player")
            let loadedPlayer: BridgePlayer = try await fetchJSON(from: url)
            player = loadedPlayer

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

            let friendsURL = baseURL.appending(path: "friends")
            do {
                friends = try await fetchJSON(from: friendsURL)
            } catch {
                friends = nil
                friendsErrorMessage = "Player loaded, but friends failed: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Could not load player data: \(error.localizedDescription)"
        }

        isLoading = false
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

struct BridgeFriends: Decodable {
    let friends: [BridgeFriend]
}

struct BridgeFriend: Decodable, Identifiable {
    let puuid: String
    let gameName: String
    let tagLine: String
    let mmr: BridgeFriendMMR?
    let mmrError: String?

    var id: String {
        puuid
    }
}

struct BridgeFriendMMR: Decodable {
    let subject: String?
    let competitiveTier: Int
    let rankedRating: Int
    let leaderboardRank: Int
    let numberOfWins: Int
    let seasonID: String?
    let hasRank: Bool

    private enum CodingKeys: String, CodingKey {
        case subject
        case competitiveTier
        case rankedRating
        case leaderboardRank
        case numberOfWins
        case seasonID
        case hasRank
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
    }

    var rankText: String {
        BridgeFriendMMR.rankName(for: competitiveTier)
    }

    private static func rankName(for tier: Int) -> String {
        switch tier {
        case 3:
            "Iron 1"
        case 4:
            "Iron 2"
        case 5:
            "Iron 3"
        case 6:
            "Bronze 1"
        case 7:
            "Bronze 2"
        case 8:
            "Bronze 3"
        case 9:
            "Silver 1"
        case 10:
            "Silver 2"
        case 11:
            "Silver 3"
        case 12:
            "Gold 1"
        case 13:
            "Gold 2"
        case 14:
            "Gold 3"
        case 15:
            "Platinum 1"
        case 16:
            "Platinum 2"
        case 17:
            "Platinum 3"
        case 18:
            "Diamond 1"
        case 19:
            "Diamond 2"
        case 20:
            "Diamond 3"
        case 21:
            "Ascendant 1"
        case 22:
            "Ascendant 2"
        case 23:
            "Ascendant 3"
        case 24:
            "Immortal 1"
        case 25:
            "Immortal 2"
        case 26:
            "Immortal 3"
        case 27:
            "Radiant"
        default:
            tier > 0 ? "Tier \(tier)" : "Unrated"
        }
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

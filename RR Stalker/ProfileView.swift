import SwiftUI
import Combine
import Foundation

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

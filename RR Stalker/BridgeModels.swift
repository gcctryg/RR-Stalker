import SwiftUI
import Combine
import Foundation

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

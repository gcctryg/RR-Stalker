import SwiftUI
import Combine
import Foundation

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

import SwiftUI
import Combine
import Foundation

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

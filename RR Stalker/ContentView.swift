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
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "desktopcomputer.and.iphone")
                    .font(.system(size: 52))
                    .foregroundStyle(.red)

                Text("RR Stalker")
                    .font(.largeTitle.bold())

                Text("Connect to your PC bridge to load player data.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await bridge.loadPlayer()
                }
            } label: {
                Label(
                    bridge.isLoading ? "Loading..." : "Load Player From PC",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(bridge.isLoading)

            if let player = bridge.player {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Player")
                        .font(.headline)

                    InfoRow(title: "Name", value: "\(player.gameName)#\(player.tagLine)")
                    InfoRow(title: "Level", value: "\(player.level)")
                    InfoRow(title: "PUUID", value: player.puuid)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if let errorMessage = bridge.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("Bridge URL: \(bridge.baseURL.absoluteString)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
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

@MainActor
final class PCBridgeClient: ObservableObject {
    @Published var player: BridgePlayer?
    @Published var errorMessage: String?
    @Published var isLoading = false

    // Replace this with your PC's local IP address.
    let baseURL = URL(string: "http://192.168.0.14:3000")!

    func loadPlayer() async {
        isLoading = true
        errorMessage = nil

        do {
            let url = baseURL.appending(path: "player")
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BridgeError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw BridgeError.badStatus(httpResponse.statusCode)
            }

            player = try JSONDecoder().decode(BridgePlayer.self, from: data)
        } catch {
            errorMessage = "Could not load player data: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

struct BridgePlayer: Decodable {
    let gameName: String
    let tagLine: String
    let puuid: String
    let level: Int
}

enum BridgeError: LocalizedError {
    case invalidResponse
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The PC bridge returned an invalid response."
        case .badStatus(let statusCode):
            "The PC bridge returned HTTP \(statusCode)."
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

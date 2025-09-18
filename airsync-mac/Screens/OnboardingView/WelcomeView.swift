//
//  WelcomeView.swift
//  AirSync
//
//  Created by Sameera Sandakelum on 2025-09-02.
//

import SwiftUI

struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 4)
            }

            Text("AirSync")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .tracking(0.5)

            Text("The forbidden continuity for you mac and Android. (っ◕‿◕)っ")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            HStack{
                GlassButtonView(
                    label: "How to use?",
                    systemImage: "questionmark.circle",
                    size: .extraLarge,
                    action: {
                        if let url = URL(string: "https://airsync.notion.site") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
                .transition(.identity)

                GlassButtonView(
                    label: "Let's Start!",
                    systemImage: "arrow.right.circle",
                    size: .extraLarge,
                    primary: true,
                    action: onNext
                )
                .transition(.identity)

            }

            Text("v\(Bundle.main.appVersion)")
        }
    }
}

#Preview {
    WelcomeView(onNext: {})
}

//
//  StatusBarOverlay.swift
//  tui-notification-toast
//
//  Created by Codex on 18.05.2026.
//

import SwiftUI

struct StatusBarOverlay: View {
    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 54, alignment: .center)

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "cellularbars")
                    .font(.system(size: 16, weight: .semibold))

                Image(systemName: "wifi")
                    .font(.system(size: 15, weight: .semibold))

                Image(systemName: "battery.100")
                    .font(.system(size: 21, weight: .regular))
            }
            .foregroundStyle(.black)
        }
        .padding(.horizontal, 28)
        .frame(height: StatusBarMetrics.contentHeight)
        .offset(y: StatusBarMetrics.topOffset)
        .frame(maxWidth: .infinity)
        .frame(height: StatusBarMetrics.height, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum StatusBarMetrics {
    static let height: CGFloat = 59
    static let topOffset: CGFloat = 18
    static let contentHeight: CGFloat = 24
}

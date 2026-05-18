//
//  ContentView.swift
//  tui-notification-toast
//
//  Created by Pavel Korostelev on 18.05.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var copiedToastTrigger = 0
    @State private var selectedPreview: PreviewScreen = .home

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            PreviewImage(screen: selectedPreview)
                .ignoresSafeArea()

            BottomProgressiveBlur()

            VStack(spacing: 16) {
                Spacer(minLength: 0)

                PreviewChips(selectedPreview: $selectedPreview)
                    .padding(.horizontal, BottomControlsMetrics.horizontalPadding)

                TuiButton(title: "Показать тост") {
                    copiedToastTrigger += 1
                }
                .padding(.horizontal, BottomControlsMetrics.horizontalPadding)
                .padding(.bottom, BottomControlsMetrics.bottomPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .topToast(trigger: copiedToastTrigger, text: "Номер скопирован", topSpacing: -54)
        .statusBarHidden(true)
        .preferredColorScheme(.light)
    }
}

private enum PreviewScreen: String, CaseIterable, Identifiable {
    case home = "Главная"
    case card = "Карточка"

    var id: Self { self }

    var assetName: String {
        switch self {
        case .home:
            return "HomePreview"
        case .card:
            return "CardPreview"
        }
    }
}

private struct PreviewImage: View {
    let screen: PreviewScreen

    var body: some View {
        GeometryReader { proxy in
            Image(screen.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .animation(.easeInOut(duration: 0.18), value: screen)
    }
}

private enum BottomControlsMetrics {
    static let horizontalPadding: CGFloat = 16
    static let bottomPadding: CGFloat = 56
    static let stackSpacing: CGFloat = 16
    static let chipHeight: CGFloat = 36
    static let buttonHeight: CGFloat = 56
    static let progressiveBlurHeight = chipHeight + stackSpacing + buttonHeight + bottomPadding
}

private struct BottomProgressiveBlur: View {
    var body: some View {
        ZStack {
            ProgressiveMaterialLayer(
                material: .ultraThinMaterial,
                clearUntil: 0.0,
                fullFrom: 0.58,
                opacity: 0.74
            )

            ProgressiveMaterialLayer(
                material: .thinMaterial,
                clearUntil: 0.22,
                fullFrom: 0.82,
                opacity: 0.78
            )

            ProgressiveMaterialLayer(
                material: .regularMaterial,
                clearUntil: 0.48,
                fullFrom: 1.0,
                opacity: 0.7
            )

            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.0), location: 0.0),
                    .init(color: Color.white.opacity(0.34), location: 0.46),
                    .init(color: Color.white.opacity(0.88), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: BottomControlsMetrics.progressiveBlurHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ProgressiveMaterialLayer: View {
    let material: Material
    let clearUntil: CGFloat
    let fullFrom: CGFloat
    let opacity: CGFloat

    var body: some View {
        Rectangle()
            .fill(material)
            .opacity(opacity)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: clearUntil),
                        .init(color: .black.opacity(0.7), location: midpoint),
                        .init(color: .black, location: fullFrom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    private var midpoint: CGFloat {
        clearUntil + ((fullFrom - clearUntil) * 0.62)
    }
}

private struct PreviewChips: View {
    @Binding var selectedPreview: PreviewScreen

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PreviewScreen.allCases) { screen in
                ChipButton(
                    title: screen.rawValue,
                    isSelected: selectedPreview == screen
                ) {
                    selectedPreview = screen
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color(red: 0.2, green: 0.2, blue: 0.2))
                .padding(.horizontal, 16)
                .frame(height: BottomControlsMetrics.chipHeight)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(.secondarySystemBackground))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.black.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct TuiButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .default))
                .tracking(-0.41)
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                .frame(maxWidth: .infinity)
                .frame(height: BottomControlsMetrics.buttonHeight)
                .background(Color(red: 1.0, green: 0.8667, blue: 0.1765))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}

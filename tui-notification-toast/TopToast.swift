//
//  TopToast.swift
//  tui-notification-toast
//
//  Created by Codex on 18.05.2026.
//

import SwiftUI

struct TopToastView: View {
    let text: String
    let icon: String
    let phase: TopToastAnimationPhase

    var body: some View {
        toastContent
            .mask(alignment: .topLeading) {
                GeometryReader { proxy in
                    Capsule(style: .continuous)
                        .frame(
                            width: phase.revealWidth(for: proxy.size.width),
                            height: proxy.size.height
                        )
                        .position(
                            x: proxy.size.width * phase.maskCenterFraction,
                            y: proxy.size.height / 2
                        )
                }
            }
            .shadow(
                color: Color.black.opacity(TopToastMetrics.shadowOpacity),
                radius: TopToastMetrics.shadowRadius,
                x: 0,
                y: TopToastMetrics.shadowYOffset
            )
            .opacity(phase.opacity)
            .blur(radius: phase.blurRadius)
            .offset(y: phase.yOffset)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
    }

    private var toastContent: some View {
        HStack(spacing: TopToastMetrics.contentSpacing) {
            ZStack {
                TopToastIconView(name: icon)
                    .opacity(phase.iconOpacity)
            }
            .frame(width: TopToastMetrics.iconSize, height: TopToastMetrics.iconSize)

            Text(text)
                .font(.system(size: TopToastMetrics.fontSize, weight: .regular))
                .foregroundStyle(TopToastMetrics.textColor)
                .lineLimit(1)
        }
        .padding(.leading, TopToastMetrics.leadingPadding)
        .padding(.trailing, TopToastMetrics.trailingPadding)
        .padding(.vertical, TopToastMetrics.verticalPadding)
        .frame(minHeight: TopToastMetrics.height)
        .fixedSize()
        .background {
            ZStack {
                Capsule(style: .continuous)
                    .fill(.regularMaterial)

                Capsule(style: .continuous)
                    .fill(TopToastMetrics.backgroundColor)
            }
        }
        .overlay {
            ToastSideFadeOverlay(opacity: phase.sideFadeOpacity)
        }
    }
}

private struct TopToastIconView: View {
    let name: String

    var body: some View {
        if name == TopToastMetrics.defaultIconName {
            Image(.toastCheckPositive)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
        } else {
            Image(systemName: name)
                .font(.system(size: TopToastMetrics.iconSize, weight: .semibold))
                .foregroundStyle(TopToastMetrics.iconColor)
        }
    }
}

private struct ToastSideFadeOverlay: View {
    let opacity: Double

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [
                    TopToastMetrics.sideFadeColor.opacity(TopToastMetrics.sideFadePeakOpacity),
                    TopToastMetrics.sideFadeColor.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: TopToastMetrics.sideFadeWidth)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    TopToastMetrics.sideFadeColor.opacity(0),
                    TopToastMetrics.sideFadeColor.opacity(TopToastMetrics.sideFadePeakOpacity)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: TopToastMetrics.sideFadeWidth)
        }
        .opacity(opacity)
        .blendMode(.screen)
        .clipShape(Capsule(style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct TopToastModifier: ViewModifier {
    @Binding var isPresented: Bool

    let text: String
    let icon: String
    let duration: TimeInterval
    let topSpacing: CGFloat

    @State private var isRendered = false
    @State private var phase: TopToastAnimationPhase = .appearingStart
    @State private var animationTask: Task<Void, Never>?
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    ZStack(alignment: .top) {
                        if isRendered {
                            TopToastView(text: text, icon: icon, phase: phase)
                                .frame(maxWidth: .infinity, alignment: .top)
                                .offset(y: topPadding(for: proxy.safeAreaInsets.top))
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
                .allowsHitTesting(false)
            }
            .task(id: isPresented) {
                await MainActor.run {
                    if isPresented {
                        presentToast()
                    } else {
                        dismissToast()
                    }
                }
            }
            .onDisappear {
                cancelScheduledWork()
            }
    }

    private func topPadding(for safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + topSpacing
    }

    private func presentToast() {
        animationTask?.cancel()
        hideTask?.cancel()

        isRendered = true
        phase = .appearingStart

        animationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: TopToastTiming.textRevealDuration)) {
                phase = .appearingText
            }
            guard await TopToastTiming.sleep(TopToastTiming.textRevealDuration) else { return }

            withAnimation(.easeOut(duration: TopToastTiming.iconRevealDuration)) {
                phase = .appearingOvershoot
            }
            guard await TopToastTiming.sleep(TopToastTiming.iconRevealDuration) else { return }

            withAnimation(.spring(response: TopToastTiming.settleResponse, dampingFraction: TopToastTiming.settleDamping)) {
                phase = .visible
            }
            guard await TopToastTiming.sleep(TopToastTiming.settleDuration) else { return }

            scheduleAutoHide()
        }
    }

    private func dismissToast() {
        animationTask?.cancel()
        hideTask?.cancel()

        guard isRendered else { return }

        animationTask = Task { @MainActor in
            withAnimation(.easeOut(duration: TopToastTiming.removeFirstStepDuration)) {
                phase = .disappearingStart
            }
            guard await TopToastTiming.sleep(TopToastTiming.removeFirstStepDuration) else { return }

            withAnimation(.easeOut(duration: TopToastTiming.removeSecondStepDuration)) {
                phase = .disappearingText
            }
            guard await TopToastTiming.sleep(TopToastTiming.removeSecondStepDuration) else { return }

            withAnimation(.easeIn(duration: TopToastTiming.removeFinalStepDuration)) {
                phase = .disappeared
            }
            guard await TopToastTiming.sleep(TopToastTiming.removeFinalStepDuration) else { return }

            isRendered = false
            phase = .appearingStart
        }
    }

    private func scheduleAutoHide() {
        let holdDuration = max(0, duration)

        hideTask = Task { @MainActor in
            guard await TopToastTiming.sleep(holdDuration) else { return }
            isPresented = false
        }
    }

    private func cancelScheduledWork() {
        animationTask?.cancel()
        hideTask?.cancel()
    }
}

struct TopToastTriggerModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let text: String
    let icon: String
    let duration: TimeInterval
    let topSpacing: CGFloat

    @State private var didObserveInitialTrigger = false
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .topToast(
                isPresented: $isPresented,
                text: text,
                icon: icon,
                duration: duration,
                topSpacing: topSpacing
            )
            .task(id: trigger) {
                await MainActor.run {
                    guard didObserveInitialTrigger else {
                        didObserveInitialTrigger = true
                        return
                    }

                    replayToast()
                }
            }
    }

    private func replayToast() {
        isPresented = false

        Task { @MainActor in
            await Task.yield()
            isPresented = true
        }
    }
}

extension View {
    func topToast(
        isPresented: Binding<Bool>,
        text: String = "Copied",
        icon: String = TopToastMetrics.defaultIconName,
        duration: TimeInterval = TopToastTiming.defaultVisibleDuration,
        topSpacing: CGFloat = TopToastMetrics.topSpacing
    ) -> some View {
        modifier(
            TopToastModifier(
                isPresented: isPresented,
                text: text,
                icon: icon,
                duration: duration,
                topSpacing: topSpacing
            )
        )
    }

    func topToast<Trigger: Equatable>(
        trigger: Trigger,
        text: String = "Copied",
        icon: String = TopToastMetrics.defaultIconName,
        duration: TimeInterval = TopToastTiming.defaultVisibleDuration,
        topSpacing: CGFloat = TopToastMetrics.topSpacing
    ) -> some View {
        modifier(
            TopToastTriggerModifier(
                trigger: trigger,
                text: text,
                icon: icon,
                duration: duration,
                topSpacing: topSpacing
            )
        )
    }
}

enum TopToastAnimationPhase {
    case appearingStart
    case appearingText
    case appearingOvershoot
    case visible
    case disappearingStart
    case disappearingText
    case disappeared

    var opacity: Double {
        switch self {
        case .appearingStart:
            return 0
        case .appearingText:
            return 0.45
        case .appearingOvershoot, .visible:
            return 1
        case .disappearingStart:
            return 0.65
        case .disappearingText:
            return 0.25
        case .disappeared:
            return 0
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .appearingStart:
            return -14
        case .appearingText:
            return -8
        case .appearingOvershoot:
            return 6
        case .visible:
            return 0
        case .disappearingStart:
            return -3
        case .disappearingText:
            return -8
        case .disappeared:
            return -12
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .appearingStart:
            return 3
        case .appearingText:
            return 3
        case .appearingOvershoot, .visible:
            return 0
        case .disappearingStart:
            return 0.5
        case .disappearingText:
            return 3.5
        case .disappeared:
            return 6
        }
    }

    func revealWidth(for finalWidth: CGFloat) -> CGFloat {
        let width: CGFloat

        switch self {
        case .appearingStart:
            width = TopToastMetrics.initialRevealWidth
        case .appearingText:
            width = min(finalWidth, TopToastMetrics.textRevealWidth)
        case .appearingOvershoot:
            width = finalWidth * 1.04
        case .visible:
            width = finalWidth
        case .disappearingStart:
            width = finalWidth * 0.80
        case .disappearingText:
            width = max(TopToastMetrics.textCollapseWidth, finalWidth * 0.58)
        case .disappeared:
            width = TopToastMetrics.initialRevealWidth
        }

        return max(1, width)
    }

    var maskCenterFraction: CGFloat {
        switch self {
        case .appearingStart:
            return 0.58
        case .appearingText:
            return 0.55
        case .appearingOvershoot, .visible:
            return 0.5
        case .disappearingStart:
            return 0.55
        case .disappearingText:
            return 0.58
        case .disappeared:
            return 0.60
        }
    }

    var iconOpacity: Double {
        switch self {
        case .appearingStart, .appearingText:
            return 0
        case .appearingOvershoot, .visible:
            return 1
        case .disappearingStart:
            return 0.35
        case .disappearingText, .disappeared:
            return 0
        }
    }

    var sideFadeOpacity: Double {
        switch self {
        case .appearingStart:
            return 0
        case .appearingText:
            return 0.85
        case .appearingOvershoot:
            return 0.38
        case .visible:
            return 0
        case .disappearingStart:
            return 0.5
        case .disappearingText:
            return 0.9
        case .disappeared:
            return 0
        }
    }
}

private enum TopToastMetrics {
    static let height: CGFloat = 48
    static let topSpacing: CGFloat = 10
    static let defaultIconName = "ToastCheckPositive"
    static let leadingPadding: CGFloat = 12
    static let trailingPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 9
    static let contentSpacing: CGFloat = 8
    static let iconSize: CGFloat = 22
    static let fontSize: CGFloat = 15
    static let shadowOpacity = 0.11
    static let shadowRadius: CGFloat = 12
    static let shadowYOffset: CGFloat = 6
    static let initialRevealWidth: CGFloat = 48
    static let textRevealWidth: CGFloat = 96
    static let textCollapseWidth: CGFloat = 84
    static let sideFadeWidth: CGFloat = 24
    static let sideFadePeakOpacity = 0.3

    static let backgroundColor = Color.white.opacity(0.88)
    static let sideFadeColor = Color.white
    static let textColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let iconColor = Color(red: 0.48, green: 0.43, blue: 0.86)
}

enum TopToastTiming {
    static let defaultVisibleDuration: TimeInterval = 1.2

    static let textRevealDuration: TimeInterval = 0.07
    static let iconRevealDuration: TimeInterval = 0.11
    static let settleDuration: TimeInterval = 0.12
    static let settleResponse = 0.22
    static let settleDamping = 0.88

    static let removeFirstStepDuration: TimeInterval = 0.08
    static let removeSecondStepDuration: TimeInterval = 0.08
    static let removeFinalStepDuration: TimeInterval = 0.07

    static func sleep(_ seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

// S-02 main screen / F-02 everyday mode / F-03 conversation mode / F-04 level meter (frame) / F-05 practice switch / F-06 headphone status / F-07 test sound / F-08 onboarding
import SwiftUI

struct ContentView: View {
    @State private var engine = HearingAudioEngine()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var showInfo = false
    /// Set when the user asks for the introduction from the info sheet; handled after that sheet is dismissed
    @State private var pendingIntroduction = false
    @State private var tipIndex = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .footnote) private var statusIconWidth = Theme.statusIconWidth
    @ScaledMetric(relativeTo: .footnote) private var statusSpacing = Theme.spaceS
    @ScaledMetric(relativeTo: .title) private var scaledButtonDiameter = Theme.mainButtonDiameter

    /// Main button diameter: grows with text size but stays capped so it remains a sensible circle
    private var mainButtonDiameter: CGFloat {
        min(max(scaledButtonDiameter, Theme.mainButtonDiameter),
            Theme.mainButtonDiameter * Theme.mainButtonMaxScale)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                content
                    .padding(.horizontal, Theme.spaceL)
                    .padding(.vertical, Theme.spaceM)
                    .frame(maxWidth: Theme.maxContentWidth)
                    // Fills the screen at normal sizes; grows and scrolls at large text sizes
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.foreground)
        .onAppear { showOnboarding = !hasSeenOnboarding }
        .onChange(of: engine.selectedProfile) { _, _ in tipIndex = 0 }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showInfo, onDismiss: {
            // Present the introduction only after the info sheet is gone (never two sheets at once)
            if pendingIntroduction {
                pendingIntroduction = false
                showOnboarding = true
            }
        }) {
            ProfileInfoSheet(engine: engine) {
                pendingIntroduction = true
                showInfo = false
            }
        }
    }

    private var content: some View {
        VStack(spacing: Theme.spaceM) {
            topBar
            ripple
            profileSummary
            if engine.mode == .conversation {
                conversationSection
            }
            profileTabs
            statusLine
            bottomControls
        }
    }

    /// Flexible in the middle at normal sizes; smaller and fixed at accessibility text sizes
    @ViewBuilder
    private var ripple: some View {
        if dynamicTypeSize.isAccessibilitySize {
            RippleView(level: 0, isActive: engine.isRunning)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.rippleAccessibilityHeight)
        } else {
            RippleView(level: 0, isActive: engine.isRunning)
                .frame(maxWidth: .infinity, minHeight: Theme.rippleMinHeight, maxHeight: .infinity)
        }
    }

    // MARK: Top bar (mode switch + info)
    private var topBar: some View {
        HStack(alignment: .top) {
            // Side by side when they fit; stacked at huge text sizes so words never break
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.spaceL) { modeButtons }
                VStack(alignment: .leading, spacing: 0) { modeButtons }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Experience mode")

            Spacer()

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title2.weight(Theme.symbolWeight))
                    .foregroundStyle(Theme.foreground)
                    .frame(minWidth: Theme.minTouchTarget, minHeight: Theme.minTouchTarget)
            }
            .accessibilityLabel("About this profile")
        }
    }

    @ViewBuilder
    private var modeButtons: some View {
        ForEach(ExperienceMode.allCases) { mode in
            selectableText(mode.title, isSelected: engine.mode == mode) {
                engine.mode = mode
            }
        }
    }

    /// Text button whose selection is shown by weight, brightness and a small dot (no color)
    private func selectableText(_ text: String, accessibilityLabel: String? = nil,
                                isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.spaceXS) {
                Text(text)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.foreground : Theme.secondary)
                    // Never break a label mid-word
                    .lineLimit(1)
                    .fixedSize()
                Circle()
                    .fill(Theme.foreground)
                    .frame(width: Theme.selectedDotSize, height: Theme.selectedDotSize)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(minHeight: Theme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? text)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Selected profile name and one-line description
    private var profileSummary: some View {
        VStack(spacing: Theme.spaceS) {
            Text(engine.selectedProfile.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                // Wrap at word boundaries; shrink slightly rather than break a long word
                .minimumScaleFactor(Theme.titleMinScale)
                // Cap only the title so its longest word still fits on one line
                .dynamicTypeSize(...Theme.titleMaxDynamicTypeSize)
                .accessibilityAddTraits(.isHeader)
            Text(engine.selectedProfile.shortDescription)
                .font(.body)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    // MARK: Conversation mode (F-03 tip + F-05 practice switch)
    private var conversationSection: some View {
        let tips = engine.selectedProfile.conversationTips
        let tip = tips[tipIndex % tips.count]
        return VStack(spacing: Theme.spaceS) {
            Button {
                tipIndex = (tipIndex + 1) % tips.count
            } label: {
                Text(tip)
                    .font(.callout)
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                    .padding(Theme.spaceS)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(Theme.line, lineWidth: Theme.thinLineWidth)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double-tap for the next tip")

            Toggle("Practice the tips", isOn: $engine.isAdviceApplied)
                .font(.body)
                .foregroundStyle(Theme.foreground)
        }
    }

    // MARK: Profile text tabs
    private var profileTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spaceL) {
                ForEach(HearingProfile.allCases) { profile in
                    selectableText(profile.tabTitle,
                                   accessibilityLabel: profile.title,
                                   isSelected: engine.selectedProfile == profile) {
                        engine.select(profile)
                    }
                }
            }
            .padding(.horizontal, Theme.spaceXS)
        }
        .frame(minHeight: Theme.minTouchTarget + Theme.selectedDotSize)
    }

    // MARK: Status line (F-06): one short line, icon + text
    private var statusLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: statusSpacing) {
            Image(systemName: status.symbol)
                .font(.footnote.weight(Theme.symbolWeight))
                .frame(width: statusIconWidth)
                .accessibilityHidden(true)
            Text(status.text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            if engine.micPermissionDenied && engine.lastErrorMessage == nil {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            }
        }
        .foregroundStyle(Theme.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }

    /// Status text and icon, by priority
    private var status: (symbol: String, text: String) {
        if let message = engine.lastErrorMessage {
            return ("exclamationmark.triangle", message)
        }
        if engine.micPermissionDenied {
            return ("mic.slash", "Microphone access is off. Allow it in Settings, or use Test Sound.")
        }
        if engine.isBluetoothOutput {
            return ("info.circle", "Wired headphones recommended — Bluetooth adds about 150 ms of delay.")
        }
        if !engine.isHeadphoneConnected && !engine.useTestSource {
            return ("headphones.slash", "Connect headphones, or turn on Test Sound in ⓘ")
        }
        if engine.isHeadphoneConnected {
            return ("headphones", "Headphones connected")
        }
        return ("speaker.wave.2", "Test Sound on")
    }

    // MARK: Bottom: volume slider + main button
    private var bottomControls: some View {
        VStack(spacing: Theme.spaceM) {
            HStack(spacing: Theme.spaceM) {
                Image(systemName: "speaker.fill")
                    .accessibilityHidden(true)
                Slider(value: $engine.outputVolume, in: 0...HearingAudioEngine.maxOutputVolume)
                    .accessibilityLabel("Volume")
                Image(systemName: "speaker.wave.3.fill")
                    .accessibilityHidden(true)
            }
            .font(.footnote.weight(Theme.symbolWeight))
            .foregroundStyle(Theme.secondary)

            mainButton
        }
    }

    private var mainButton: some View {
        let isDisabled = engine.isStopping || (!engine.isRunning && !engine.canStart)
        return Button {
            if engine.isRunning {
                engine.stop()
            } else {
                Task { await engine.start() }
            }
        } label: {
            Image(systemName: engine.isRunning ? "stop.fill" : "play.fill")
                .font(.title.weight(Theme.symbolWeight))
                .foregroundStyle(Theme.background)
                .frame(width: mainButtonDiameter, height: mainButtonDiameter)
                .background(Theme.foreground, in: Circle())
                .opacity(isDisabled ? Theme.disabledOpacity : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(engine.isRunning ? "Stop listening" : "Start listening")
    }
}

#Preview {
    ContentView()
}

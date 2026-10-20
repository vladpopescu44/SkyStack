import SwiftUI

/// Preferences, progress reset and app information, presented as a paper sheet.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    let onClose: () -> Void

    init(viewModel: SettingsViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var settings = viewModel.settings
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Settings")
                        .font(.display(28, weight: .black))
                        .foregroundStyle(Theme.Colors.ink)
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark") }
                        .buttonStyle(PaperIconButtonStyle(size: 40))
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier(AccessibilityID.Settings.closeButton)
                }
                .padding(.top, 18)

                group(title: "How you drop blocks") {
                    HStack(spacing: 12) {
                        ForEach(ControlScheme.allCases) { scheme in
                            controlOption(scheme, isSelected: settings.controlScheme == scheme) {
                                settings.controlScheme = scheme
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.Settings.controlPicker)
                }

                group(title: "Feel") {
                    Toggle(isOn: $settings.hapticsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haptic feedback")
                                .font(.display(16, weight: .bold))
                                .foregroundStyle(Theme.Colors.ink)
                            Text("A tap on every landing, a thud when the tower falls.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.inkSoft)
                        }
                    }
                    .tint(Theme.Colors.leaf)
                    .onChange(of: settings.hapticsEnabled) { _, _ in viewModel.hapticsChanged() }
                    .accessibilityIdentifier(AccessibilityID.Settings.hapticsToggle)
                }

                group(title: "Progress") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Demolish and start over")
                                .font(.display(16, weight: .bold))
                                .foregroundStyle(Theme.Colors.ink)
                            Text("Removes stars, upgrades, builders and the logbook.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.inkSoft)
                        }
                        Spacer()
                        Button("Reset", action: viewModel.requestReset)
                            .buttonStyle(BlockButtonStyle(color: Theme.Colors.coral, compact: true))
                            .accessibilityIdentifier(AccessibilityID.Settings.resetButton)
                    }
                }

                group(title: "About") {
                    aboutRow("Version", viewModel.appVersion)
                    aboutRow("Support", "support@skystack.space")
                    Text("Sky Stack keeps your progress only on this device. No account, no tracking, no network.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.Colors.paperShade.ignoresSafeArea())
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .confirmationDialog(
            "Reset all progress?",
            isPresented: $viewModel.isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Reset everything", role: .destructive, action: viewModel.confirmReset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Your stars, upgrades, hired builders and logbook will be erased.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Settings.screen)
    }

    private func controlOption(_ scheme: ControlScheme, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: scheme.systemImage)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.Colors.sky : Theme.Colors.inkFaint)
                    .frame(height: 32)
                Text(scheme.title)
                    .font(.display(14, weight: .bold))
                    .foregroundStyle(Theme.Colors.ink)
                Text(scheme == .tap ? "Tap anywhere on the sky" : "Big button under the tower")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.Colors.sky.opacity(0.1) : Theme.Colors.paperShade)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isSelected ? Theme.Colors.sky : .clear, lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scheme.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.Colors.inkFaint)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 20)
    }

    private func aboutRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.inkSoft)
        }
    }
}

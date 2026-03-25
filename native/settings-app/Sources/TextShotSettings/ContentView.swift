import SwiftUI
import KeyboardShortcuts

enum SettingsActionError: Error {
    case message(String)
}

extension SettingsActionError {
    var displayMessage: String {
        switch self {
        case .message(let message):
            return message
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: EditableSettings
    @Published var errorMessage = ""
    @Published var warningMessage = ""
    @Published var recorderShortcut: AppHotkeyShortcut?
    @Published private(set) var automaticallyChecksForUpdates: Bool

    let hotkeyController: any HotkeyManaging & HotkeyRecorderBindingProviding
    let updateManager: UpdateManaging

    private let onApplySettings: (EditableSettings) -> Result<EditableSettings, SettingsActionError>

    init(
        initialSettings: EditableSettings,
        hotkeyController: any HotkeyManaging & HotkeyRecorderBindingProviding,
        updateManager: UpdateManaging,
        onApplySettings: @escaping (EditableSettings) -> Result<EditableSettings, SettingsActionError>
    ) {
        self.settings = initialSettings
        self.hotkeyController = hotkeyController
        self.updateManager = updateManager
        self.onApplySettings = onApplySettings
        self.recorderShortcut = hotkeyController.activeShortcut
        self.automaticallyChecksForUpdates = updateManager.automaticallyChecksForUpdates

        if let shortcut = hotkeyController.activeShortcut {
            var updated = settings
            updated.hotkey = HotkeyManager.displayString(for: shortcut)
            settings = updated
        }
    }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.settings.launchAtLogin },
            set: { self.updateSetting { $0.launchAtLogin = $1 }($0) }
        )
    }

    var showConfirmationBinding: Binding<Bool> {
        Binding(
            get: { self.settings.showConfirmation },
            set: { self.updateSetting { $0.showConfirmation = $1 }($0) }
        )
    }

    var recorderAvailabilityIssue: String? {
        hotkeyController.recorderAvailabilityIssue
    }

    var updateStatusMessage: String {
        updateManager.statusDescription
    }

    var canCheckForUpdates: Bool {
        updateManager.canCheckForUpdates
    }

    var canOpenUpdateInterface: Bool {
        updateManager.canConfigureAutomaticChecks || updateManager.canCheckForUpdates
    }

    var canConfigureAutomaticUpdateChecks: Bool {
        updateManager.canConfigureAutomaticChecks
    }

    var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { self.automaticallyChecksForUpdates },
            set: { self.setAutomaticUpdateChecks($0) }
        )
    }

    func onRecorderError(_ message: String) {
        errorMessage = message
    }

    func onRecorderWarning(_ message: String?) {
        warningMessage = message ?? ""
    }

    func syncHotkeyDisplay(with shortcut: AppHotkeyShortcut?) {
        recorderShortcut = shortcut

        var updated = settings
        updated.hotkey = HotkeyManager.displayString(for: shortcut)
        settings = updated
    }

    func checkForUpdates() {
        updateManager.checkForUpdates()
    }

    private func setAutomaticUpdateChecks(_ enabled: Bool) {
        updateManager.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = updateManager.automaticallyChecksForUpdates
    }

    private func updateSetting(_ transform: @escaping (inout EditableSettings, Bool) -> Void) -> (Bool) -> Void {
        { [weak self] value in
            guard let self else {
                return
            }

            let previous = self.settings
            var next = previous
            transform(&next, value)

            switch self.onApplySettings(next) {
            case .success(let persisted):
                self.settings = persisted
                self.errorMessage = ""

            case .failure(let error):
                self.settings = previous
                self.errorMessage = error.displayMessage
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: SettingsViewModel

    private let settingsWidth: CGFloat = 430
    private let settingsHeight: CGFloat = 348
    private let horizontalPadding: CGFloat = 18
    private let verticalPadding: CGFloat = 14
    private let columnSpacing: CGFloat = 12
    private let controlColumnFraction: CGFloat = 0.34
    private let minimumRowHeight: CGFloat = 30

    private var contentWidth: CGFloat {
        settingsWidth - (horizontalPadding * 2)
    }

    private var controlColumnWidth: CGFloat {
        floor(contentWidth * controlColumnFraction)
    }

    private var labelColumnWidth: CGFloat {
        contentWidth - controlColumnWidth - columnSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            hotkeyRow

            toggleRow(
                title: "Launch At Login",
                isOn: model.launchAtLoginBinding
            )

            toggleRow(
                title: "Show Confirmation Pulse",
                isOn: model.showConfirmationBinding
            )

            updateActionRow

            automaticUpdatesRow
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(width: settingsWidth, height: settingsHeight, alignment: .topLeading)
    }

    private var hotkeyRow: some View {
        settingsRow(title: "Global Hotkey") {
            VStack(alignment: .leading, spacing: 6) {
                if let issue = model.recorderAvailabilityIssue {
                    Text(issue)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                } else {
                    KeyboardShortcutField(
                        hotkeyController: model.hotkeyController,
                        shortcut: $model.recorderShortcut,
                        onError: { model.onRecorderError($0) },
                        onWarning: { model.onRecorderWarning($0) }
                    )
                    .frame(height: 28, alignment: .center)
                }

                if !model.errorMessage.isEmpty {
                    Text(model.errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }

                if !model.warningMessage.isEmpty {
                    Text(model.warningMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        settingsRow(title: title) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var updateActionRow: some View {
        settingsRow(title: "Updates") {
            Button("Check for Updates...") {
                model.checkForUpdates()
            }
            .disabled(!model.canOpenUpdateInterface)
            .help(model.updateStatusMessage)
        }
    }

    private var automaticUpdatesRow: some View {
        settingsRow(title: "Check for Updates Automatically") {
            Toggle("", isOn: model.automaticUpdateChecksBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(!model.canConfigureAutomaticUpdateChecks)
                .help(model.updateStatusMessage)
        }
    }

    private func settingsRow<Control: View>(
        title: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: alignment, spacing: columnSpacing) {
            Text(title)
                .font(.system(size: 13))
                .frame(width: labelColumnWidth, alignment: .leading)
            control()
                .frame(width: controlColumnWidth, alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: minimumRowHeight, alignment: .leading)
    }
}

import SwiftUI

struct HomeDashboardView: View {
    @Binding var isWindowManagementEnabled: Bool
    @EnvironmentObject private var appConfig: AppConfig
    @EnvironmentObject private var stageManagerSettings: StageManagerSettings
    @EnvironmentObject private var dockSettings: DockSettings
    @State private var isShowingIndividualCompanionSettings = false

    private var state: HomeDashboardState {
        HomeDashboardState(
            appRules: appConfig.appRules,
            isEnabled: isWindowManagementEnabled,
            isStageManagerEnabled: stageManagerSettings.isEnabled,
            isDockAutohideEnabled: dockSettings.isAutohideEnabled,
            windowScaleFactor: appConfig.windowScaleFactor
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dashboardHeader
                heroControlCard
                companionControlCard
                scaleControlCard
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .onAppear {
            stageManagerSettings.reload()
            dockSettings.reload()
        }
    }
}

private extension HomeDashboardView {
    var companionBinding: Binding<Bool> {
        Binding(
            get: { state.isCompanionEnabled },
            set: { targetEnabled in
                applyCompanionChange(targetEnabled: targetEnabled)
            }
        )
    }

    var stageManagerBinding: Binding<Bool> {
        Binding(
            get: { stageManagerSettings.isEnabled },
            set: { newValue in
                stageManagerSettings.setEnabled(newValue)
            }
        )
    }

    var dockAutohideBinding: Binding<Bool> {
        Binding(
            get: { dockSettings.isAutohideEnabled },
            set: { newValue in
                dockSettings.setAutohideEnabled(newValue)
            }
        )
    }

    var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.headerTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(state.headerSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var companionControlCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    companionStatusBadge

                    Text(state.companionTitle)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(state.companionDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Toggle(state.companionToggleTitle, isOn: companionBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(state.companionToggleTitle)
                    .font(.headline)

                Text(state.companionToggleSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(companionErrorMessages.enumerated()), id: \.offset) { _, message in
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            DisclosureGroup(isExpanded: $isShowingIndividualCompanionSettings) {
                VStack(spacing: 0) {
                    individualCompanionSettingRow(
                        title: state.stageManagerTitle,
                        statusTitle: state.stageManagerStatusTitle,
                        subtitle: state.stageManagerToggleSubtitle,
                        systemImage: "rectangle.stack",
                        binding: stageManagerBinding
                    )

                    Divider()
                        .padding(.leading, 44)

                    individualCompanionSettingRow(
                        title: state.dockAutohideTitle,
                        statusTitle: state.dockAutohideStatusTitle,
                        subtitle: state.dockAutohideToggleSubtitle,
                        systemImage: "dock.rectangle",
                        binding: dockAutohideBinding
                    )
                }
                .padding(.top, 10)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.individualSettingsTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(state.individualSettingsSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(systemControlCardBackground(cornerRadius: 22))
    }

    var heroControlCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    statusBadge

                    Text(state.heroTitle)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(state.heroDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Toggle("", isOn: $isWindowManagementEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(1.15)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(state.heroToggleTitle)
                    .font(.headline)

                Text(state.heroToggleSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground)
    }

    var scaleControlCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(state.scaleTitle)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(state.scaleDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Text(state.scaleText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            }

            Slider(value: $appConfig.windowScaleFactor, in: 0.80...1.00, step: 0.01)
                .tint(.blue)

            HStack {
                Text("更紧凑")
                Spacer()
                Text("更宽松")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(state.scaleFootnote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scaleCardBackground)
    }

    var statusBadge: some View {
        Label(state.statusTitle, systemImage: isWindowManagementEnabled ? "checkmark.circle.fill" : "pause.circle.fill")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.10))
            )
    }

    var heroCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
            )
    }

    var scaleCardBackground: some View {
        standardCardBackground(cornerRadius: 22)
    }

    func systemControlCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
            )
    }

    var companionStatusBadge: some View {
        Label(state.companionStatusTitle, systemImage: companionStatusSystemImage)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.10))
            )
    }

    var companionStatusSystemImage: String {
        switch state.companionStatus {
        case .enabled:
            return "checkmark.circle.fill"
        case .partial:
            return "circle.lefthalf.filled"
        case .disabled:
            return "sparkles"
        }
    }

    var companionErrorMessages: [String] {
        var messages: [String] = []

        if let errorMessage = stageManagerSettings.lastErrorMessage {
            messages.append("\(state.stageManagerErrorPrefix)\(errorMessage)")
        }

        if let errorMessage = dockSettings.lastErrorMessage {
            messages.append("\(state.dockAutohideErrorPrefix)\(errorMessage)")
        }

        return messages
    }

    func applyCompanionChange(targetEnabled: Bool) {
        let plan = state.companionChangePlan(targetEnabled: targetEnabled)
        AppLogger.shared.log(
            "请求\(targetEnabled ? "开启" : "关闭") Maru 风格好搭子组合设置",
            level: .info
        )

        if let stageManagerTarget = plan.stageManagerTarget {
            stageManagerSettings.setEnabled(stageManagerTarget)
        }

        if let dockAutohideTarget = plan.dockAutohideTarget {
            dockSettings.setAutohideEnabled(dockAutohideTarget)
        }
    }

    func individualCompanionSettingRow(
        title: String,
        statusTitle: String,
        subtitle: String,
        systemImage: String,
        binding: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(statusTitle) · \(subtitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle(title, isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    func standardCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.10), lineWidth: 1)
            )
    }
}

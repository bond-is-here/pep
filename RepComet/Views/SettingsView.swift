import SwiftUI

struct SettingsView: View {
    var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var showBackup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    RCHeader(title: "Make it yours.", subtitle: "A little more you. A little more Pep.")
                    RCThemePicker()
                    if let error = store.persistenceError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.callout).foregroundStyle(RCTheme.text)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        FlowFieldLabel(title: "WEIGHT UNIT")
                        HStack(spacing: 12) {
                            ForEach(WeightUnit.allCases) { unit in
                                Button { store.setUnit(unit) } label: {
                                    VStack(spacing: 7) {
                                        Text(unit.symbol).font(.system(size: 28, weight: .semibold, design: .rounded))
                                        Text(unit.title).font(.system(size: 12, weight: .medium))
                                    }.frame(maxWidth: .infinity).padding(.vertical, 20)
                                        .foregroundStyle(store.unit == unit ? RCTheme.onAccent : RCTheme.muted)
                                        .background(store.unit == unit ? RCTheme.accent : RCTheme.card, in: RoundedRectangle(cornerRadius: 20))
                                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(store.unit == unit ? Color.clear : RCTheme.border, lineWidth: 1))
                                }.buttonStyle(RCPressStyle()).disabled(store.isReadOnly).accessibilityAddTraits(store.unit == unit ? .isSelected : [])
                                    .accessibilityIdentifier("settings.unit.\(unit.symbol)")
                            }
                        }
                        Text("Applies to your workout weights and body weight. Your existing entries convert automatically.")
                            .font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        FlowFieldLabel(title: "WEEKLY RHYTHM")
                        HStack(spacing: 18) {
                            goalButton(symbol: "minus", disabled: store.weeklyGoal <= 1) { store.setWeeklyGoal(store.weeklyGoal - 1) }
                            VStack(spacing: 4) {
                                Text("\(store.weeklyGoal)").font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit()
                                Text("workouts / week").font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                            }.frame(maxWidth: .infinity)
                            goalButton(symbol: "plus", disabled: store.weeklyGoal >= 7) { store.setWeeklyGoal(store.weeklyGoal + 1) }
                        }.padding(20).rcSurface(padding: 0)
                        Text("Pick a rhythm that fits your life. Rest days count as taking care of yourself, too.")
                            .font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        FlowFieldLabel(title: "YOUR LOG, TO GO")
                        Text("A little peace of mind.").font(.system(.title3, design: .rounded, weight: .bold))
                        Text("Save a backup to Files and bring it with you to a new device. You choose where it goes.")
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(RCTheme.muted)
                        RCSecondaryButton(title: "Back up & restore", icon: "externaldrive") { showBackup = true }
                            .accessibilityIdentifier("settings.backup")
                    }.rcSurface()

                    VStack(alignment: .leading, spacing: 18) {
                        FlowFieldLabel(title: "GOOD THINGS, NO CATCH")
                        VStack(spacing: 0) {
                            promiseRow(symbol: "sparkles", title: "Free. All of it.", detail: "Every routine, every workout, every check-in. No subscriptions or locked features.")
                            Divider().overlay(RCTheme.border).padding(.horizontal, 20)
                            promiseRow(symbol: "wifi.slash", title: "Ready wherever you are", detail: "No account needed. Your training works without an internet connection.")
                            Divider().overlay(RCTheme.border).padding(.horizontal, 20)
                            promiseRow(symbol: "lock.shield", title: "Your data stays yours", detail: "Your log is stored locally on this device. No ads, trackers, or data collection.")
                        }.rcSurface(padding: 0)
                    }
                    VStack(spacing: 7) {
                        Text("Pep").font(.system(size: 32, weight: .heavy, design: .rounded))
                        Text("A little effort. A lot to feel good about.").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted)
                        Text("Version 1.0").font(.system(size: 11)).foregroundStyle(RCTheme.muted).padding(.top, 5)
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                }.padding(22)
            }
            .foregroundStyle(RCTheme.text).background(RCTheme.background.ignoresSafeArea()).preferredColorScheme(RCAppearance.shared.colorScheme)
            .navigationTitle("Settings").navigationBarTitleDisplayModeIfAvailable()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundStyle(RCTheme.accentText) } }
            .sheet(isPresented: $showBackup) { BackupView(store: store) }
        }
    }

    private func goalButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(width: 48, height: 48)
                .foregroundStyle(RCTheme.accentText).background(RCTheme.background, in: Circle())
                .overlay(Circle().stroke(RCTheme.border, lineWidth: 1))
        }.buttonStyle(RCPressStyle()).disabled(disabled).opacity(disabled ? 0.3 : 1)
            .accessibilityLabel(symbol == "plus" ? "Increase weekly workout goal" : "Decrease weekly workout goal")
    }

    private func promiseRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: symbol).font(.system(size: 21, weight: .regular)).foregroundStyle(RCTheme.accentText).frame(width: 26).padding(.top, 3)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                Text(detail).font(.system(size: 12)).foregroundStyle(RCTheme.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(20)
    }
}

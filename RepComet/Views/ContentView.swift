import SwiftUI

private enum MainTab: String, CaseIterable {
    case today = "Today"
    case routines = "Routines"
    case progress = "Progress"

    var symbol: String {
        switch self {
        case .today: return "square.grid.2x2"
        case .routines: return "dumbbell"
        case .progress: return "chart.xyaxis.line"
        }
    }
}

struct ContentView: View {
    let store: WorkoutStore
    @State private var selectedTab: MainTab = .today
    @State private var showSettings = false
    @Namespace private var tabHighlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Bool { !reduceMotion && RCAppearance.shared.motionEnabled }

    var body: some View {
        NavigationStack {
            ZStack {
                RCBackground()
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text("pep.")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .tracking(-2.4).foregroundStyle(RCTheme.text)
                        Text("YOUR\nWORKOUT BUDDY")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .tracking(1.15).lineSpacing(2).foregroundStyle(RCTheme.muted)
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(RCTheme.text).frame(width: 44, height: 44)
                                .background(RCTheme.card, in: Circle())
                                .overlay(Circle().stroke(RCTheme.border, lineWidth: 1))
                        }.buttonStyle(RCPressStyle()).accessibilityLabel("Settings and appearance")
                    }.padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 12)
                    Group {
                        switch selectedTab {
                        case .today: TodayView(store: store, openRoutines: { select(.routines) })
                        case .routines: RoutinesView(store: store)
                        case .progress: ProgressScreenView(store: store)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(selectedTab)
                        .transition(motion ? .opacity.combined(with: .offset(y: 7)) : .identity)
                    if let error = store.persistenceError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange).padding(.horizontal, 24).padding(.vertical, 8)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .rcHideNavigationBar()
        }
        .preferredColorScheme(RCAppearance.shared.colorScheme)
        .tint(RCTheme.accent)
        .sheet(isPresented: $showSettings) { SettingsView(store: store) }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                let selected = selectedTab == tab
                Button {
                    RCTheme.impact()
                    select(tab)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol).font(.system(size: 19, weight: selected ? .semibold : .regular))
                            .frame(height: 22)
                        Text(tab.rawValue).font(.system(size: 11, weight: selected ? .bold : .medium, design: .rounded))
                    }.foregroundStyle(selected ? RCTheme.accentText : RCTheme.muted)
                        .frame(maxWidth: .infinity).frame(height: 57)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 19).fill(RCTheme.accent.opacity(0.11))
                                    .matchedGeometryEffect(id: "selected-tab", in: tabHighlight)
                            }
                        }
                }.buttonStyle(RCPressStyle()).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 6)
            .background(RCTheme.card)
            .overlay(alignment: .top) { Rectangle().fill(RCTheme.border).frame(height: 1) }
    }

    private func select(_ tab: MainTab) {
        guard tab != selectedTab else { return }
        withAnimation(motion ? .spring(response: 0.4, dampingFraction: 0.82) : nil) {
            selectedTab = tab
        }
    }
}

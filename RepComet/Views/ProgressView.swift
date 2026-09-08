import SwiftUI
import Charts

struct ProgressScreenView: View {
    let store: WorkoutStore
    @State private var showWeightEntry = false
    @State private var selectedSession: WorkoutSession?
    @State private var showHistory = false
    @State private var showWeightHistory = false

    private var orderedWeights: [WeightEntry] { store.weights.sorted { $0.date < $1.date } }
    private var recentSessions: [WorkoutSession] { store.sessions.sorted { $0.startedAt > $1.startedAt } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                RCHeader(title: "Your little wins.", subtitle: "Every workout adds up. Here's your happy proof.").rcEntrance()
                HStack(spacing: 12) {
                    metric(value: "\(store.sessions.count)", title: "SESSIONS", symbol: "bolt.fill")
                    metric(value: volumeString, title: "\(store.unit.symbol.uppercased()) LIFTED", symbol: "dumbbell")
                }
                weeklyActivity
                weightProgress
                history
                Text("Your pace. Your progress. Plenty to feel good about.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(RCTheme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.bottom, 25)
            }.padding(.horizontal, 24).padding(.top, 12)
        }
        .sheet(isPresented: $showWeightEntry) { WeightEntryView(store: store) }
        .sheet(isPresented: $showWeightHistory) { WeightHistoryView(store: store) }
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                SessionDetailView(session: session, unit: store.unit)
                    .toolbar { ToolbarItem(placement: .automatic) { Button("Done") { selectedSession = nil }.tint(RCTheme.accentText) } }
            }.preferredColorScheme(RCAppearance.shared.colorScheme)
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                ZStack {
                    RCBackground()
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(recentSessions) { session in
                                NavigationLink { SessionDetailView(session: session, unit: store.unit) } label: { sessionRow(session) }
                                    .buttonStyle(RCPressStyle())
                            }
                        }.padding(24)
                    }
                }.navigationTitle("Your sessions")
                    .toolbar { ToolbarItem(placement: .automatic) { Button("Done") { showHistory = false }.tint(RCTheme.accentText) } }
            }.preferredColorScheme(RCAppearance.shared.colorScheme)
        }
    }

    private var volumeString: String {
        let amount = store.unit.value(fromKilograms: store.totalVolumeKG)
        if amount >= 10000 { return String(format: "%.1fk", amount / 1000) }
        return amount.formatted(.number.precision(.fractionLength(0)))
    }

    private func metric(value: String, title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(RCTheme.accentText)
            VStack(alignment: .leading, spacing: 6) {
                Text(value).font(.system(size: 35, weight: .bold, design: .rounded)).tracking(-1.2).foregroundStyle(RCTheme.text)
                Text(title).font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(0.8).foregroundStyle(RCTheme.muted)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).rcSurface(padding: 19).accessibilityElement(children: .combine)
    }

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("This week's good stuff").font(.system(size: 18, weight: .bold, design: .rounded)).tracking(-0.4).foregroundStyle(RCTheme.text)
                    Text("\(store.sessionsThisWeek.count) of \(store.weeklyGoal) sessions completed").font(.system(size: 11)).foregroundStyle(RCTheme.muted)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis").font(.system(size: 18)).foregroundStyle(RCTheme.accentText)
            }
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(currentWeek, id: \.self) { day in
                    let count = store.sessions.filter { Calendar.current.isDate($0.finishedAt ?? $0.startedAt, inSameDayAs: day) }.count
                    let today = Calendar.current.isDateInToday(day)
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6).fill(RCTheme.background).frame(height: 80)
                            if count > 0 {
                                RoundedRectangle(cornerRadius: 6).fill(RCTheme.accent)
                                    .frame(height: CGFloat(count) / CGFloat(maxDailySessions) * 80)
                            } else {
                                RoundedRectangle(cornerRadius: 3).fill(today ? RCTheme.accent.opacity(0.25) : RCTheme.border).frame(height: 4)
                            }
                        }
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 11, weight: today ? .bold : .medium, design: .rounded)).foregroundStyle(today ? RCTheme.accentText : RCTheme.muted)
                    }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(count) workouts")
                }
            }
            if store.sessionsThisWeek.isEmpty {
                Text("One workout is a lovely place to start.").font(.system(size: 12, design: .rounded)).foregroundStyle(RCTheme.muted)
            }
        }.rcSurface()
    }

    private var currentWeek: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstDay = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: firstDay) }
    }

    private var maxDailySessions: Int {
        max(1, currentWeek.map { day in store.sessions.filter { Calendar.current.isDate($0.finishedAt ?? $0.startedAt, inSameDayAs: day) }.count }.max() ?? 1)
    }

    private var weightProgress: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                RCSectionLabel(title: "Weight check-ins")
                Button { showWeightEntry = true } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(RCTheme.accentText)
                        .frame(width: 44, height: 44).background(RCTheme.accent.opacity(0.08), in: Circle())
                }.buttonStyle(RCPressStyle()).accessibilityLabel("Add weight check-in")
            }
            if let latest = orderedWeights.last {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(store.unit.value(fromKilograms: latest.kilograms).formatted(.number.precision(.fractionLength(1))))
                            .font(.system(size: 38, weight: .bold, design: .rounded)).tracking(-1.5).foregroundStyle(RCTheme.text)
                        Text(store.unit.symbol).font(.system(size: 15)).foregroundStyle(RCTheme.muted)
                        Spacer()
                        Text(latest.date.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 11)).foregroundStyle(RCTheme.muted)
                    }
                    Text(orderedWeights.count == 1 ? "A starting point, at your own pace." : "Your check-ins over time.")
                        .font(.system(size: 11)).foregroundStyle(RCTheme.muted)
                }
                Chart(orderedWeights) { entry in
                    LineMark(x: .value("Date", entry.date), y: .value("Weight", store.unit.value(fromKilograms: entry.kilograms)))
                        .foregroundStyle(RCTheme.secondary).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    PointMark(x: .value("Date", entry.date), y: .value("Weight", store.unit.value(fromKilograms: entry.kilograms)))
                        .foregroundStyle(RCTheme.secondary).symbolSize(orderedWeights.count == 1 ? 55 : 22)
                }
                .chartYScale(domain: weightRange)
                .chartXScale(domain: dateRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(RCTheme.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(RCTheme.border)
                        AxisValueLabel().foregroundStyle(RCTheme.muted)
                    }
                }.frame(height: 145).padding(.top, 8)
                    .accessibilityLabel("Body weight history in \(store.unit.symbol)")
                ForEach(Array(orderedWeights.reversed().prefix(3))) { entry in
                    HStack {
                        Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year())).foregroundStyle(RCTheme.muted)
                        Spacer()
                        Text("\(store.unit.value(fromKilograms: entry.kilograms).formatted(.number.precision(.fractionLength(1)))) \(store.unit.symbol)").foregroundStyle(RCTheme.text)
                    }.font(.system(size: 12)).padding(.vertical, 5)
                        .accessibilityElement(children: .combine)
                }
                RCSecondaryButton(title: "View check-ins", icon: "clock.arrow.circlepath") { showWeightHistory = true }
            } else {
                RCEmptyState(symbol: "scalemass", title: "More than a number.", message: "Track your weight when it feels right. Your first check-in gives you a starting point.")
                RCSecondaryButton(title: "Log your first check-in", icon: "plus") { showWeightEntry = true }
            }
        }.rcSurface()
    }

    private var weightRange: ClosedRange<Double> {
        let values = orderedWeights.map { store.unit.value(fromKilograms: $0.kilograms) }
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let pad = max(1, (high - low) * 0.2)
        return max(0, low - pad)...(high + pad)
    }

    private var dateRange: ClosedRange<Date> {
        let first = orderedWeights.first?.date ?? Date()
        let last = orderedWeights.last?.date ?? first
        if first == last { return first.addingTimeInterval(-43200)...last.addingTimeInterval(43200) }
        let padding = max(3600, last.timeIntervalSince(first) * 0.05)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                RCSectionLabel(title: "Your recent sessions")
                if recentSessions.count > 3 {
                    Button { showHistory = true } label: {
                        Text("See all").font(.system(size: 11, weight: .medium)).frame(minWidth: 44, minHeight: 44)
                    }.tint(RCTheme.accentText)
                }
            }
            if recentSessions.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    RCSymbolBadge(symbol: "clock.arrow.circlepath")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your next win goes here.").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
                        Text("Finish a workout and your session history will live here.")
                            .font(.system(size: 12)).foregroundStyle(RCTheme.muted).lineSpacing(4)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).rcSurface()
            } else {
                ForEach(Array(recentSessions.prefix(3))) { session in
                    Button { selectedSession = session } label: { sessionRow(session) }.buttonStyle(RCPressStyle())
                }
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 13) {
            RCSymbolBadge(symbol: "checkmark")
            VStack(alignment: .leading, spacing: 5) {
                Text(session.routineName).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
                Text("\(session.startedAt.formatted(.dateTime.month(.abbreviated).day())) · \(session.completedSets) sets · \(max(1, Int(session.duration / 60))) min")
                    .font(.system(size: 11)).foregroundStyle(RCTheme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium)).foregroundStyle(RCTheme.muted)
        }.rcSurface(padding: 15)
    }
}

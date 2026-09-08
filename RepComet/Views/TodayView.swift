import SwiftUI

struct TodayView: View {
    let store: WorkoutStore
    var openRoutines: () -> Void
    @State private var showWorkout = false
    @State private var showWeightEntry = false
    @State private var chosenRoutineID: UUID?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var nextRoutine: Routine? {
        store.routines.first(where: { $0.id == chosenRoutineID }) ?? store.suggestedRoutine
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstDay = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: firstDay) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                greeting.rcEntrance(delay: 0.02)
                Group {
                    if let active = store.activeSession {
                        activeCard(active)
                    } else if let routine = nextRoutine {
                        nextWorkoutCard(routine)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            RCEmptyState(symbol: "figure.strengthtraining.traditional", title: "Let's find your moves.", message: "Pick the exercises you like. Build a little routine. You've got this.")
                            RCPrimaryButton(title: "Make your first routine", icon: "plus", action: openRoutines)
                        }.rcSurface()
                    }
                }.rcEntrance(delay: 0.07)
                weeklyGoal.rcEntrance(delay: 0.12)
                MomentumCard(momentum: store.momentum).rcEntrance(delay: 0.14)
                weightCheckIn.rcEntrance(delay: 0.17)
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").font(.system(size: 10))
                    Text("A little effort. A lot of good. Always free.")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }.foregroundStyle(RCTheme.muted).frame(maxWidth: .infinity).padding(.bottom, 16)
            }.padding(.horizontal, 22).padding(.top, 8)
        }
        .rcWorkoutPresentation(isPresented: $showWorkout) { WorkoutView(store: store) }
        .sheet(isPresented: $showWeightEntry) { WeightEntryView(store: store) }
        .onChange(of: store.sessions.count) { _, _ in chosenRoutineID = nil }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(RCTheme.muted)
            VStack(alignment: .leading, spacing: -1) {
                Text("A little pep.").foregroundStyle(RCTheme.text)
                Text("A stronger you.").foregroundStyle(RCTheme.accentText)
            }
            .font(.system(.largeTitle, design: .rounded, weight: .heavy)).tracking(-1.5)
            .fixedSize(horizontal: false, vertical: true).minimumScaleFactor(0.75)
        }
    }

    private func nextWorkoutCard(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold))
                        Text("UP NEXT").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1)
                    }.foregroundStyle(RCTheme.accentText)
                    Text(displayName(routine.name))
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy)).tracking(-1.2)
                        .lineSpacing(-2).foregroundStyle(RCTheme.text)
                        .fixedSize(horizontal: false, vertical: true).minimumScaleFactor(0.75)
                    Text("\(routine.estimatedMinutes) min  ·  \(routine.exercises.count) exercises")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(RCTheme.text.opacity(0.74)).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    PepBuddy().frame(width: 105, height: 120).padding(.trailing, -3)
                }
            }
            if chosenRoutineID == nil, !store.sessions.isEmpty {
                Text(store.lastCompletedDate(for: routine) == nil ? "A fresh one to try. Your choice, always." : "Rotated from your log. Go at your own pace.")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(RCTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            RCPrimaryButton(title: "Start workout", icon: "arrow.right") {
                _ = store.startWorkout(routine)
                showWorkout = store.activeSession != nil
            }.accessibilityIdentifier("today.start-workout").disabled(store.isReadOnly)
            Menu {
                ForEach(store.routines) { alternative in
                    Button(alternative.name) { chosenRoutineID = alternative.id }
                }
                Divider()
                Button("Edit my routines", action: openRoutines)
            } label: {
                Label("Choose a different routine", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(RCTheme.accentText).frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityIdentifier("today.choose-routine")
        }
        .padding(18)
        .background(LinearGradient(colors: [RCTheme.heroStart, RCTheme.heroStart, RCTheme.heroEnd.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 29, style: .continuous).stroke(RCTheme.accent.opacity(0.1), lineWidth: 1))
    }

    private func activeCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("YOU'RE DOING GREAT", systemImage: "bolt.fill")
                        .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.6).foregroundStyle(RCTheme.accentText)
                    Text(session.routineName).font(.system(size: 29, weight: .heavy, design: .rounded))
                        .tracking(-1).foregroundStyle(RCTheme.text).fixedSize(horizontal: false, vertical: true)
                    Text("\(session.completedSets) sets down. Keep it going!")
                        .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize { PepBuddy().frame(width: 106, height: 120) }
            }
            RCPrimaryButton(title: "Resume workout", icon: "arrow.right") { showWorkout = true }
                .accessibilityIdentifier("today.resume-workout")
        }.padding(18)
            .background(RCTheme.heroStart, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 29, style: .continuous).stroke(RCTheme.accent.opacity(0.1), lineWidth: 1))
    }

    private var weeklyGoal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Little wins this week")
                    .font(.system(size: 16, weight: .heavy, design: .rounded)).tracking(-0.3).foregroundStyle(RCTheme.text)
                Spacer(minLength: 0)
                Text("\(store.sessionsThisWeek.count) / \(store.weeklyGoal)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundStyle(RCTheme.accentText).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(RCTheme.accent.opacity(0.09), in: Capsule())
                    .accessibilityLabel("\(store.sessionsThisWeek.count) of \(store.weeklyGoal) weekly workouts complete")
            }
            HStack(spacing: 7) {
                ForEach(weekDays, id: \.self) { day in
                    let isToday = Calendar.current.isDateInToday(day)
                    let completed = store.weeklyCompletedDays.contains { Calendar.current.isDate($0, inSameDayAs: day) }
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(isToday ? RCTheme.onAccent.opacity(0.8) : RCTheme.muted)
                        ZStack {
                            if completed {
                                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy))
                            } else {
                                Text(day.formatted(.dateTime.day())).font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                        }.frame(height: 19).foregroundStyle(isToday ? RCTheme.onAccent : RCTheme.text)
                        Circle().fill(completed ? (isToday ? RCTheme.onAccent : RCTheme.secondary) : Color.clear).frame(width: 3, height: 3)
                    }.frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(isToday ? RCTheme.accent : RCTheme.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(isToday ? Color.clear : RCTheme.border, lineWidth: 1))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day()))\(isToday ? ", today" : "")\(completed ? ", workout completed" : "")")
                }
            }
        }
    }

    private var weightCheckIn: some View {
        Button { showWeightEntry = true } label: {
            HStack(spacing: 12) {
                RCSymbolBadge(symbol: "scalemass", color: RCTheme.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A little check-in")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
                    if let latest = store.weights.max(by: { $0.date < $1.date }) {
                        Text("Last: \(store.unit.value(fromKilograms: latest.kilograms).formatted(.number.precision(.fractionLength(1)))) \(store.unit.symbol) · Add weight")
                            .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted)
                    } else {
                        Text("Track your weight. Only if you want to.")
                            .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RCTheme.secondary).frame(width: 30, height: 30)
                    .background(RCTheme.secondary.opacity(0.08), in: Circle())
            }.rcSurface(padding: 14)
        }.buttonStyle(RCPressStyle()).accessibilityLabel("Log your body weight, optional")
            .disabled(store.isReadOnly)
    }

    private func displayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "upper body" { return "Upper\nbody" }
        if trimmed.lowercased() == "lower body" { return "Lower\nbody" }
        if trimmed.lowercased() == "full body" { return "Full\nbody" }
        return trimmed
    }
}

import SwiftUI

struct RoutinesView: View {
    let store: WorkoutStore
    @State private var editingRoutine: Routine?
    @State private var showCreateRoutine = false
    @State private var showWorkout = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Moves you love.")
                        .font(.system(size: 34, weight: .heavy, design: .rounded)).tracking(-1.3).foregroundStyle(RCTheme.text)
                    Text("A plan for your kind of strong.")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted)
                }.rcEntrance(delay: 0.02)
                HStack {
                    Text("YOUR ROUTINES").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(RCTheme.muted)
                    Spacer()
                    Text("\(store.routines.count) ready to go")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.accentText)
                }
                if store.routines.isEmpty {
                    RCEmptyState(symbol: "dumbbell", title: "Make room for your moves.", message: "Build your first routine, choose a few exercises, and start getting stronger.").rcSurface()
                } else {
                    VStack(spacing: 15) {
                        ForEach(Array(store.routines.enumerated()), id: \.element.id) { index, routine in
                            routineCard(routine, index: index).rcEntrance(delay: 0.04 + Double(min(index, 5)) * 0.04)
                        }
                    }
                }
                RCPrimaryButton(title: "Make a new routine", icon: "plus") { showCreateRoutine = true }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkle").foregroundStyle(RCTheme.accentText)
                    Text("Start with one of ours, or do your own thing. Every move, every routine. Always free.")
                        .foregroundStyle(RCTheme.muted).lineSpacing(5)
                }.font(.system(size: 12, weight: .medium, design: .rounded)).padding(.horizontal, 3).padding(.bottom, 24)
            }.padding(.horizontal, 22).padding(.top, 8)
        }
        .sheet(item: $editingRoutine) { RoutineEditorView(store: store, routine: $0) }
        .sheet(isPresented: $showCreateRoutine) { RoutineEditorView(store: store) }
        .rcWorkoutPresentation(isPresented: $showWorkout) { WorkoutView(store: store) }
    }

    private func routineCard(_ routine: Routine, index: Int) -> some View {
        let activeRoutine = store.activeSession.map { active in
            if let routineID = active.routineID { return routineID == routine.id }
            return active.routineName.caseInsensitiveCompare(routine.name) == .orderedSame
        } ?? false
        let workoutInProgress = store.activeSession != nil
        return VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 9) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(RCTheme.accentText).frame(width: 33, height: 33)
                    .background(RCTheme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 11))
                Text("YOUR KIND OF STRONG")
                    .font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(1).foregroundStyle(RCTheme.muted)
                Spacer(minLength: 0)
                Button { editingRoutine = routine } label: {
                    Image(systemName: "pencil").font(.system(size: 14, weight: .semibold)).foregroundStyle(RCTheme.text)
                        .frame(width: 44, height: 44).background(RCTheme.card.opacity(0.7), in: Circle())
                }.buttonStyle(RCPressStyle()).accessibilityLabel("Edit \(routine.name)")
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.name).font(.system(size: 28, weight: .heavy, design: .rounded)).tracking(-0.8).foregroundStyle(RCTheme.text)
                    Text(routine.subtitle.isEmpty ? "Your pace. Your plan." : routine.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted).lineLimit(2)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: routine.symbol).font(.system(size: 29, weight: .semibold))
                    .rotationEffect(.degrees(index % 2 == 0 ? -12 : 10))
                    .foregroundStyle(index % 2 == 0 ? RCTheme.accentText : RCTheme.secondary)
                    .frame(width: 54, height: 54)
                    .background(RCTheme.card.opacity(0.56), in: RoundedRectangle(cornerRadius: 19))
            }
            HStack(spacing: 12) {
                Label("\(routine.estimatedMinutes) min", systemImage: "clock")
                Circle().fill(RCTheme.border).frame(width: 3, height: 3)
                Text("\(routine.exercises.count) exercises")
                Spacer()
                Text("\(routine.exercises.reduce(0) { $0 + $1.sets }) sets")
            }.font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(RCTheme.muted)
            HStack(spacing: 10) {
                Button { editingRoutine = routine } label: {
                    Text("View routine").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
                        .frame(maxWidth: .infinity).frame(minHeight: 46).background(RCTheme.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(RCPressStyle())
                Button {
                    RCTheme.impact()
                    if store.activeSession == nil {
                        _ = store.startWorkout(routine)
                    }
                    showWorkout = store.activeSession != nil
                } label: {
                    HStack(spacing: 10) {
                        Text(workoutInProgress ? (activeRoutine ? "Resume" : "Finish current") : "Let's go")
                        Image(systemName: workoutInProgress && !activeRoutine ? "lock.fill" : "arrow.right")
                    }.font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.onAccent)
                        .frame(maxWidth: .infinity).frame(minHeight: 46).background(RCTheme.accent, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(RCPressStyle())
                .disabled(workoutInProgress && !activeRoutine)
                .opacity(workoutInProgress && !activeRoutine ? 0.55 : 1)
                .accessibilityLabel(workoutInProgress ? (activeRoutine ? "Resume active \(routine.name) workout" : "Finish the active workout before starting \(routine.name)") : "Start \(routine.name)")
            }
        }.padding(18)
            .background(index % 2 == 0 ? RCTheme.heroStart.opacity(0.72) : RCTheme.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(RCTheme.border, lineWidth: 1))
    }
}

import SwiftUI

struct WorkoutView: View {
    var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscard = false
    @State private var showingFinish = false
    @State private var completedSession: WorkoutSession?
    @State private var invalidSetIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if let completedSession {
                    completionView(completedSession)
                } else if let session = store.activeSession {
                    workoutContent(session)
                } else {
                    RCEmptyState(symbol: "figure.strengthtraining.traditional", title: "Ready when you are.", message: "Choose a routine and let's get moving.")
                }
            }
            .background(RCTheme.background.ignoresSafeArea())
            .preferredColorScheme(RCAppearance.shared.colorScheme)
            .navigationBarTitleDisplayModeIfAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(completedSession == nil ? "Minimize" : "Done") { dismiss() }
                        .foregroundStyle(RCTheme.muted)
                }
                if completedSession == nil, store.activeSession != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Discard workout", systemImage: "trash", role: .destructive) { showingDiscard = true }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44)
                        }.tint(RCTheme.text)
                    }
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $showingDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { store.discardWorkout(); dismiss() }
            } message: { Text("The sets from this workout will be permanently removed.") }
            .confirmationDialog("Finish your workout?", isPresented: $showingFinish, titleVisibility: .visible) {
                Button("Save completed sets") {
                    if let saved = store.finishWorkout() { completedSession = saved }
                }
            } message: { Text("Only completed sets will count toward your workout history.") }
        }
    }

    private func workoutContent(_ session: WorkoutSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 8) {
                    Circle().fill(RCTheme.accent).frame(width: 6, height: 6)
                    Text("LET’S DO THIS").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1)
                }.foregroundStyle(RCTheme.accentText)
                Text(session.routineName).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)

                HStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        FlowMetric(title: "ELAPSED", value: FlowFormat.duration(context.date.timeIntervalSince(session.startedAt)))
                    }
                    Divider().overlay(RCTheme.border).padding(.vertical, 5)
                    FlowMetric(title: "SETS DONE", value: "\(session.completedSets)")
                    Divider().overlay(RCTheme.border).padding(.vertical, 5)
                    FlowMetric(title: "VOLUME · \(store.unit.symbol.uppercased())", value: FlowFormat.number(store.unit.value(fromKilograms: session.volumeKG)))
                }.padding(.vertical, 18).rcSurface(padding: 0)

                if let deadline = store.restEndsAt {
                    restCard(deadline)
                }

                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseLoggingCard(store: store, exercise: exercise, index: index + 1) { setID, isValid in
                        if isValid { invalidSetIDs.remove(setID) } else { invalidSetIDs.insert(setID) }
                    }
                }

                VStack(spacing: 12) {
                    RCPrimaryButton(title: "Finish workout", icon: "checkmark") { showingFinish = true }
                        .disabled(session.completedSets == 0 || !invalidSetIDs.isEmpty)
                        .opacity(session.completedSets == 0 || !invalidSetIDs.isEmpty ? 0.45 : 1)
                    Text(!invalidSetIDs.isEmpty ? "Check your weight and rep entries before finishing." : session.completedSets == 0 ? "Check off your first set to save this workout." : "Your completed sets are saved as you go.")
                        .font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                        .multilineTextAlignment(.center)
                }.padding(.top, 4)
            }.padding(20).padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func restCard(_ deadline: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(ceil(deadline.timeIntervalSince(context.date))))
            HStack(spacing: 14) {
                Image(systemName: remaining > 0 ? "timer" : "checkmark.circle.fill")
                    .font(.system(size: 24)).foregroundStyle(RCTheme.accentText)
                VStack(alignment: .leading, spacing: 4) {
                    Text(remaining > 0 ? "Breathe. You earned it." : "Ready for your next set.").font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(remaining > 0 ? "REST TIMER" : "REST COMPLETE").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.8).foregroundStyle(RCTheme.muted)
                }
                Spacer(minLength: 4)
                Text(FlowFormat.duration(TimeInterval(remaining))).font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                Button { store.clearRest() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(RCTheme.muted).accessibilityLabel("Skip rest timer")
            }
            .foregroundStyle(RCTheme.text).padding(16)
            .background(RCTheme.accent.opacity(0.075), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(RCTheme.accent.opacity(0.3), lineWidth: 1))
        }
    }

    private func completionView(_ session: WorkoutSession) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                RCCompletionMark().padding(.top, 20)
                VStack(spacing: 8) {
                    Text("Look at you go!").font(.system(size: 34, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
                    Text("Every set counts. You showed up.").font(.system(size: 15, design: .rounded)).foregroundStyle(RCTheme.muted)
                    Text(session.routineName).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(RCTheme.muted)
                }
                HStack(spacing: 0) {
                    FlowMetric(title: "TIME", value: FlowFormat.duration(session.duration))
                    FlowMetric(title: "SETS", value: "\(session.completedSets)")
                    FlowMetric(title: store.unit.symbol.uppercased(), value: FlowFormat.number(store.unit.value(fromKilograms: session.volumeKG)))
                }.padding(.vertical, 22).rcSurface(padding: 0)
                RCPrimaryButton(title: "Back to Today", icon: "arrow.right") { dismiss() }
                Text("A little stronger. A little more Pep.").font(.system(size: 12, design: .rounded)).foregroundStyle(RCTheme.muted)
            }.padding(24).foregroundStyle(RCTheme.text)
        }
    }
}

private struct ExerciseLoggingCard: View {
    var store: WorkoutStore
    let exercise: SessionExercise
    let index: Int
    let onValidation: (UUID, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d", index)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.accentText).padding(.top, 3)
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name).font(.system(size: 18, weight: .bold, design: .rounded))
                    Label("\(exercise.restSeconds)s rest between sets", systemImage: "timer")
                        .font(.system(size: 11)).foregroundStyle(RCTheme.muted)
                }
                Spacer(minLength: 0)
                Text("\(exercise.sets.filter(\.isComplete).count)/\(exercise.sets.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.muted)
            }
            HStack(spacing: 10) {
                Text("SET").frame(width: 30)
                Text(store.unit.symbol.uppercased()).frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("DONE").frame(width: 44)
                Color.clear.frame(width: 44, height: 1)
            }.font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.8).foregroundStyle(RCTheme.muted)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                WorkoutSetRow(store: store, exerciseID: exercise.id, set: set, number: setIndex + 1, restSeconds: exercise.restSeconds, canRemove: exercise.sets.count > 1, onValidation: onValidation)
            }
            Button { store.addSet(exerciseID: exercise.id) } label: {
                Label("Add set", systemImage: "plus").font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(RCTheme.muted)
                .background(RCTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        }.padding(18).foregroundStyle(RCTheme.text).rcSurface(padding: 0)
    }
}

private struct WorkoutSetRow: View {
    var store: WorkoutStore
    let exerciseID: UUID
    let set: WorkoutSet
    let number: Int
    let restSeconds: Int
    let canRemove: Bool
    let onValidation: (UUID, Bool) -> Void
    @State private var weightText: String
    @State private var repsText: String
    @State private var showingError = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: Field?
    private enum Field { case weight, reps }

    init(store: WorkoutStore, exerciseID: UUID, set: WorkoutSet, number: Int, restSeconds: Int, canRemove: Bool, onValidation: @escaping (UUID, Bool) -> Void) {
        self.store = store
        self.exerciseID = exerciseID
        self.set = set
        self.number = number
        self.restSeconds = restSeconds
        self.canRemove = canRemove
        self.onValidation = onValidation
        _weightText = State(initialValue: FlowFormat.number(store.unit.value(fromKilograms: set.weightKG)))
        _repsText = State(initialValue: String(set.reps))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Text("\(number)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(set.isComplete ? RCTheme.accentText : RCTheme.muted).frame(width: 30)
                TextField("0", text: $weightText)
                    .flowDecimalKeyboard().focused($focusedField, equals: .weight)
                    .accessibilityLabel("Set \(number) weight in \(store.unit.symbol)")
                    .onChange(of: weightText) { _, _ in persistIfValid() }
                    .modifier(FlowNumberField())
                TextField("8", text: $repsText)
                    .flowIntegerKeyboard().focused($focusedField, equals: .reps)
                    .accessibilityLabel("Set \(number) repetitions")
                    .onChange(of: repsText) { _, _ in persistIfValid() }
                    .modifier(FlowNumberField())
                Button {
                    guard persistIfValid() else { showingError = true; return }
                    focusedField = nil
                    let wasComplete = set.isComplete
                    guard store.toggleSet(exerciseID: exerciseID, setID: set.id) else { return }
                    RCTheme.impact()
                    if !wasComplete { store.beginRest(seconds: restSeconds) }
                } label: {
                    Image(systemName: "checkmark")
                        .scaleEffect(set.isComplete && !reduceMotion && RCAppearance.shared.motionEnabled ? 1.10 : 1)
                        .animation(reduceMotion || !RCAppearance.shared.motionEnabled ? nil : .spring(response: 0.32, dampingFraction: 0.5), value: set.isComplete)
                        .font(.system(size: 16, weight: .bold)).frame(width: 44, height: 44)
                        .foregroundStyle(set.isComplete ? RCTheme.onAccent : RCTheme.muted)
                        .background(set.isComplete ? RCTheme.accent : RCTheme.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(set.isComplete ? Color.clear : RCTheme.border, lineWidth: 1))
                }.buttonStyle(RCPressStyle()).accessibilityLabel(set.isComplete ? "Mark set \(number) incomplete" : "Complete set \(number)")
                Button(role: .destructive) {
                    if store.removeSet(exerciseID: exerciseID, setID: set.id) { onValidation(set.id, true) }
                } label: {
                    Image(systemName: "minus.circle").font(.system(size: 15)).frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(RCTheme.muted).disabled(!canRemove).opacity(canRemove ? 1 : 0.25)
                    .accessibilityLabel("Remove set \(number)")
            }
            if showingError { Text("Use a valid weight and at least 1 rep.").font(.system(size: 11)).foregroundStyle(.orange).padding(.leading, 40) }
        }
        .onChange(of: store.unit) { _, newUnit in weightText = FlowFormat.number(newUnit.value(fromKilograms: set.weightKG)) }
        .onChange(of: focusedField) { _, field in
            if field == nil { showingError = !persistIfValid() }
        }
    }

    @discardableResult private func persistIfValid() -> Bool {
        guard let weight = FlowFormat.parseNumber(weightText), weight >= 0,
              let reps = Int(repsText), reps > 0, reps <= 1000 else {
            onValidation(set.id, false)
            return false
        }
        guard store.updateSet(exerciseID: exerciseID, setID: set.id, reps: reps, weightKG: store.unit.kilograms(from: weight)) else {
            onValidation(set.id, false)
            return false
        }
        onValidation(set.id, true)
        showingError = false
        return true
    }
}

struct FlowMetric: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 7) {
            Text(value).font(.system(size: 23, weight: .semibold, design: .rounded)).contentTransition(.numericText()).animation(reduceMotion || !RCAppearance.shared.motionEnabled ? nil : .easeOut(duration: 0.2), value: value).monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
            Text(title).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.7).foregroundStyle(RCTheme.muted)
        }.foregroundStyle(RCTheme.text).frame(maxWidth: .infinity)
    }
}

struct FlowNumberField: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 16, weight: .medium, design: .rounded)).monospacedDigit()
            .multilineTextAlignment(.center).padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: 44)
            .textFieldStyle(.plain).foregroundStyle(RCTheme.text)
            .background(RCTheme.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RCTheme.border, lineWidth: 1))
    }
}

enum FlowFormat {
    static func number(_ value: Double, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    static func parseNumber(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, normalized.allSatisfy({ "0123456789.".contains($0) }), normalized.filter({ $0 == "." }).count <= 1,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        if seconds >= 3600 { return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

extension View {
    @ViewBuilder func flowDecimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
    @ViewBuilder func flowIntegerKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
    @ViewBuilder func navigationBarTitleDisplayModeIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

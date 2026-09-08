import SwiftUI

private enum WorkoutInputField: Hashable {
    case weight(UUID)
    case reps(UUID)
}

private struct WorkoutNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct WorkoutView: View {
    var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscard = false
    @State private var showingFinish = false
    @State private var completedSession: WorkoutSession?
    @State private var invalidSetIDs: Set<UUID> = []
    @State private var notice: WorkoutNotice?
    @FocusState private var focusedInput: WorkoutInputField?

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
                    Button(completedSession == nil ? "Minimize" : "Done") {
                        if invalidSetIDs.isEmpty { focusedInput = nil; dismiss() }
                        else {
                            notice = WorkoutNotice(title: "Check your entries", message: "An unfinished weight or rep entry needs attention. Fix that entry or remove its set before minimizing so your changes are kept.")
                        }
                    }
                        .foregroundStyle(RCTheme.muted)
                        .accessibilityIdentifier(completedSession == nil ? "workout.minimize" : "workout.close")
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
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedInput = nil }.accessibilityIdentifier("workout.keyboard-done")
                }
                #endif
            }
            .interactiveDismissDisabled(!invalidSetIDs.isEmpty)
            .alert(item: $notice) { item in
                Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("Keep editing")))
            }
            .confirmationDialog("Discard this workout?", isPresented: $showingDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) {
                    if store.discardWorkout() { dismiss() } else { showSaveFailure() }
                }
            } message: { Text("The sets from this workout will be permanently removed.") }
            .confirmationDialog("Finish your workout?", isPresented: $showingFinish, titleVisibility: .visible) {
                Button("Save completed sets") {
                    if let saved = store.finishWorkout() { completedSession = saved }
                    else { showSaveFailure() }
                }
            } message: { Text("Only completed sets will count toward your workout history.") }
        }
    }

    private func showSaveFailure() {
        notice = WorkoutNotice(title: "Your workout is still open", message: store.persistenceError ?? "Pep couldn't save the workout. Keep editing and try again; your current sets are still here.")
    }

    private func workoutContent(_ session: WorkoutSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 8) {
                    Circle().fill(RCTheme.accent).frame(width: 6, height: 6)
                    Text("LET’S DO THIS").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1)
                }.foregroundStyle(RCTheme.accentText)
                Text(session.routineName).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)

                if let error = store.persistenceError {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(store.hasUnsavedChanges ? "Your changes need saving" : "A note about your data", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(error).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                        if store.hasUnsavedChanges {
                            Button("Retry save") { store.save() }
                                .font(.system(size: 14, weight: .semibold)).frame(minHeight: 44)
                                .accessibilityIdentifier("workout.retry-save")
                        }
                    }.foregroundStyle(RCTheme.text).rcSurface()
                        .accessibilityIdentifier("workout.save-error")
                }

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
                    ExerciseLoggingCard(store: store, exercise: exercise, index: index + 1, focusedInput: $focusedInput) { setID, isValid in
                        if isValid { invalidSetIDs.remove(setID) } else { invalidSetIDs.insert(setID) }
                    }
                }

                VStack(spacing: 12) {
                    RCPrimaryButton(title: "Finish workout", icon: "checkmark") { showingFinish = true }
                        .accessibilityIdentifier("workout.finish")
                        .disabled(session.completedSets == 0 || !invalidSetIDs.isEmpty)
                        .opacity(session.completedSets == 0 || !invalidSetIDs.isEmpty ? 0.45 : 1)
                    Text(!invalidSetIDs.isEmpty ? "Check your weight and rep entries before finishing." : session.completedSets == 0 ? "Check off your first set to save this workout." : store.hasUnsavedChanges ? "Keep Pep open and retry saving before you finish." : "Your completed sets are saved as you go.")
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
                        .accessibilityIdentifier("workout.completed")
                    Text("Every set counts. You showed up.").font(.system(size: 15, design: .rounded)).foregroundStyle(RCTheme.muted)
                    Text(session.routineName).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(RCTheme.muted)
                }
                HStack(spacing: 0) {
                    FlowMetric(title: "TIME", value: FlowFormat.duration(session.duration))
                    FlowMetric(title: "SETS", value: "\(session.completedSets)")
                    FlowMetric(title: store.unit.symbol.uppercased(), value: FlowFormat.number(store.unit.value(fromKilograms: session.volumeKG)))
                }.padding(.vertical, 22).rcSurface(padding: 0)
                RCPrimaryButton(title: "Done", icon: "checkmark") { dismiss() }
                    .accessibilityIdentifier("workout.done")
                Text("A little stronger. A little more Pep.").font(.system(size: 12, design: .rounded)).foregroundStyle(RCTheme.muted)
            }.padding(24).foregroundStyle(RCTheme.text)
        }
    }
}

private struct ExerciseLoggingCard: View {
    var store: WorkoutStore
    let exercise: SessionExercise
    let index: Int
    let focusedInput: FocusState<WorkoutInputField?>.Binding
    let onValidation: (UUID, Bool) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d", index)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.accentText).padding(.top, 3)
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name).font(.system(.headline, design: .rounded))
                    Label("\(exercise.restSeconds)s rest between sets", systemImage: "timer")
                        .font(.caption).foregroundStyle(RCTheme.muted)
                }
                Spacer(minLength: 0)
                Text("\(exercise.sets.filter(\.isComplete).count)/\(exercise.sets.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.muted)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 10) {
                    Text("SET").frame(width: 30)
                    Text(store.unit.symbol.uppercased()).frame(maxWidth: .infinity)
                    Text("REPS").frame(maxWidth: .infinity)
                    Text("DONE").frame(width: 44)
                    Color.clear.frame(width: 44, height: 1)
                }.font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.8).foregroundStyle(RCTheme.muted)
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                WorkoutSetRow(store: store, exerciseID: exercise.id, exerciseIndex: index - 1, set: set, number: setIndex + 1, restSeconds: exercise.restSeconds, canRemove: exercise.sets.count > 1, focusedInput: focusedInput, onValidation: onValidation)
            }
            Button { store.addSet(exerciseID: exercise.id) } label: {
                Label(exercise.sets.count < 20 ? "Add set" : "20-set limit reached", systemImage: "plus").font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(RCTheme.muted)
                .background(RCTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                .disabled(exercise.sets.count >= 20).opacity(exercise.sets.count < 20 ? 1 : 0.5)
                .accessibilityIdentifier("workout.add-set.\(index - 1)")
        }.padding(18).foregroundStyle(RCTheme.text).rcSurface(padding: 0)
    }
}

private struct WorkoutSetRow: View {
    var store: WorkoutStore
    let exerciseID: UUID
    let exerciseIndex: Int
    let set: WorkoutSet
    let number: Int
    let restSeconds: Int
    let canRemove: Bool
    let focusedInput: FocusState<WorkoutInputField?>.Binding
    let onValidation: (UUID, Bool) -> Void
    @State private var weightDraft: WorkoutWeightDraft
    @State private var repsText: String
    @State private var showingError = false
    @Environment(\.pepReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var useAccessibleLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    init(store: WorkoutStore, exerciseID: UUID, exerciseIndex: Int, set: WorkoutSet, number: Int, restSeconds: Int, canRemove: Bool, focusedInput: FocusState<WorkoutInputField?>.Binding, onValidation: @escaping (UUID, Bool) -> Void) {
        self.store = store
        self.exerciseID = exerciseID
        self.exerciseIndex = exerciseIndex
        self.set = set
        self.number = number
        self.restSeconds = restSeconds
        self.canRemove = canRemove
        self.focusedInput = focusedInput
        self.onValidation = onValidation
        _weightDraft = State(initialValue: WorkoutWeightDraft(kilograms: set.weightKG, unit: store.unit))
        _repsText = State(initialValue: WorkoutNumberInput.format(Double(set.reps), maximumFractionDigits: 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if useAccessibleLayout {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Set \(number)").font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(set.isComplete ? RCTheme.accentText : RCTheme.text)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight · \(store.unit.symbol)").font(.headline)
                        weightField
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repetitions").font(.headline)
                        repsField
                    }
                    completionButton
                    removeButton
                }.padding(.vertical, 12)
            } else {
                HStack(spacing: 10) {
                    Text("\(number)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(set.isComplete ? RCTheme.accentText : RCTheme.muted).frame(width: 30)
                    weightField
                    repsField
                    completionButton
                    removeButton
                }
            }
            if showingError {
                Text("Enter 0–\(FlowFormat.number(store.unit.value(fromKilograms: 1_500))) \(store.unit.symbol) and 1–1,000 reps.")
                    .font(useAccessibleLayout ? .callout : .system(size: 11)).foregroundStyle(RCTheme.accentText)
                    .padding(.leading, useAccessibleLayout ? 0 : 40).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("workout.set.error.\(exerciseIndex).\(number - 1)")
            }
        }
        .onChange(of: store.unit) { _, newUnit in weightDraft = WorkoutWeightDraft(kilograms: set.weightKG, unit: newUnit) }
        .onChange(of: focusedInput.wrappedValue) { old, new in
            if (old == .weight(set.id) || old == .reps(set.id)), new != .weight(set.id), new != .reps(set.id) {
                showingError = !persistIfValid()
            }
        }
    }

    private var weightField: some View {
        TextField("0", text: $weightDraft.text)
            .flowDecimalKeyboard().focused(focusedInput, equals: .weight(set.id))
            .accessibilityLabel("Set \(number) weight in \(store.unit.symbol)")
            .accessibilityIdentifier("workout.set.weight.\(exerciseIndex).\(number - 1)")
            .onChange(of: weightDraft.text) { _, _ in showingError = !persistIfValid() }
            .modifier(FlowNumberField())
    }

    private var repsField: some View {
        TextField("8", text: $repsText)
            .flowIntegerKeyboard().focused(focusedInput, equals: .reps(set.id))
            .accessibilityLabel("Set \(number) repetitions")
            .accessibilityIdentifier("workout.set.reps.\(exerciseIndex).\(number - 1)")
            .onChange(of: repsText) { _, _ in showingError = !persistIfValid() }
            .modifier(FlowNumberField())
    }

    private var completionButton: some View {
        Button {
            guard persistIfValid() else { showingError = true; return }
            focusedInput.wrappedValue = nil
            let wasComplete = store.activeSession?.exercises.first(where: { $0.id == exerciseID })?.sets.first(where: { $0.id == set.id })?.isComplete ?? set.isComplete
            guard store.toggleSet(exerciseID: exerciseID, setID: set.id) else { return }
            RCTheme.impact()
            if !wasComplete { store.beginRest(seconds: restSeconds) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .scaleEffect(set.isComplete && !reduceMotion && RCAppearance.shared.motionEnabled ? 1.10 : 1)
                    .animation(reduceMotion || !RCAppearance.shared.motionEnabled ? nil : .spring(response: 0.32, dampingFraction: 0.5), value: set.isComplete)
                    .font(.system(size: 16, weight: .bold)).frame(width: 44, height: 44)
                if useAccessibleLayout {
                    Text(set.isComplete ? "Mark incomplete" : "Complete set")
                        .font(.system(.body, design: .rounded, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }.frame(maxWidth: useAccessibleLayout ? .infinity : nil, minHeight: 44)
                .padding(.horizontal, useAccessibleLayout ? 10 : 0).padding(.vertical, useAccessibleLayout ? 8 : 0)
                .foregroundStyle(set.isComplete ? RCTheme.onAccent : RCTheme.muted)
                .background(set.isComplete ? RCTheme.accent : RCTheme.background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(set.isComplete ? Color.clear : RCTheme.border, lineWidth: 1))
        }.buttonStyle(RCPressStyle()).accessibilityLabel(set.isComplete ? "Mark set \(number) incomplete" : "Complete set \(number)")
            .accessibilityIdentifier("workout.set.complete.\(exerciseIndex).\(number - 1)")
    }

    private var removeButton: some View {
        Button(role: .destructive) {
            focusedInput.wrappedValue = nil
            if store.removeSet(exerciseID: exerciseID, setID: set.id) { onValidation(set.id, true) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "minus.circle").font(.system(size: 15)).frame(width: 44, height: 44)
                if useAccessibleLayout {
                    Text("Remove set").font(.system(.body, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }.frame(maxWidth: useAccessibleLayout ? .infinity : nil, minHeight: 44)
                .padding(.horizontal, useAccessibleLayout ? 10 : 0)
                .padding(.vertical, useAccessibleLayout ? 8 : 0)
        }.buttonStyle(.plain).foregroundStyle(RCTheme.muted).disabled(!canRemove).opacity(canRemove ? 1 : 0.25)
            .accessibilityLabel("Remove set \(number)")
            .accessibilityIdentifier("workout.set.remove.\(exerciseIndex).\(number - 1)")
    }

    @discardableResult private func persistIfValid() -> Bool {
        guard store.activeSession?.exercises.first(where: { $0.id == exerciseID })?.sets.contains(where: { $0.id == set.id }) == true else {
            onValidation(set.id, true)
            return false
        }
        guard let kilograms = weightDraft.kilograms(unit: store.unit),
              let reps = WorkoutNumberInput.integer(repsText), reps > 0, reps <= 1000 else {
            onValidation(set.id, false)
            return false
        }
        guard store.updateSet(exerciseID: exerciseID, setID: set.id, reps: reps, weightKG: kilograms) else {
            onValidation(set.id, false)
            return false
        }
        weightDraft.accept(kilograms: kilograms)
        onValidation(set.id, true)
        showingError = false
        return true
    }
}

struct FlowMetric: View {
    @Environment(\.pepReduceMotion) private var reduceMotion
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.font(dynamicTypeSize.isAccessibilitySize ? .system(.body, design: .rounded, weight: .medium) : .system(size: 16, weight: .medium, design: .rounded)).monospacedDigit()
            .multilineTextAlignment(.center).padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: 44)
            .textFieldStyle(.plain).foregroundStyle(RCTheme.text)
            .background(RCTheme.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RCTheme.border, lineWidth: 1))
    }
}

enum FlowFormat {
    static func number(_ value: Double, maximumFractionDigits: Int = 2) -> String {
        WorkoutNumberInput.format(value, maximumFractionDigits: maximumFractionDigits)
    }
    static func parseNumber(_ text: String) -> Double? {
        WorkoutNumberInput.decimal(text)
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

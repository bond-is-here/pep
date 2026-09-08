import SwiftUI

struct RoutineEditorView: View {
    var store: WorkoutStore
    let routine: Routine?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var exercises: [ExerciseTemplate]
    @State private var symbol: String
    @State private var showingLibrary = false
    @State private var showingDelete = false
    @State private var showingDiscard = false
    @State private var error: String?
    private let symbols = ["dumbbell.fill", "bolt.fill", "figure.strengthtraining.traditional", "figure.run", "flame.fill", "sparkles"]

    init(store: WorkoutStore, routine: Routine? = nil) {
        self.store = store
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _exercises = State(initialValue: routine?.exercises ?? [])
        _symbol = State(initialValue: routine?.symbol ?? "dumbbell.fill")
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty }
    private var hasChanges: Bool { name != (routine?.name ?? "") || exercises != (routine?.exercises ?? []) || symbol != (routine?.symbol ?? "dumbbell.fill") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    RCHeader(title: routine == nil ? "Your kind of workout." : "A little fine-tuning.", subtitle: "Pick your moves. Make them yours.")
                    VStack(alignment: .leading, spacing: 14) {
                        FlowFieldLabel(title: "ROUTINE NAME")
                        TextField("e.g. Monday feel-good", text: $name)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .padding(17).background(RCTheme.card, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(RCTheme.border, lineWidth: 1))
                            .textFieldStyle(.plain).onChange(of: name) { _, value in if value.count > 80 { name = String(value.prefix(80)) } }
                        HStack(spacing: 10) {
                            ForEach(symbols, id: \.self) { icon in
                                Button { symbol = icon } label: {
                                    Image(systemName: icon).font(.system(size: 17, weight: .medium))
                                        .frame(maxWidth: .infinity, minHeight: 46)
                                        .foregroundStyle(symbol == icon ? RCTheme.onAccent : RCTheme.muted)
                                        .background(symbol == icon ? RCTheme.accent : RCTheme.card, in: RoundedRectangle(cornerRadius: 13))
                                }.buttonStyle(RCPressStyle()).accessibilityLabel("\(iconLabel(icon)) routine icon")
                                    .accessibilityAddTraits(symbol == icon ? .isSelected : [])
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            FlowFieldLabel(title: "YOUR EXERCISES")
                            Spacer()
                            Text("\(exercises.count) selected").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted)
                        }
                        if exercises.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "sparkles").font(.system(size: 26)).foregroundStyle(RCTheme.accentText)
                                Text("Great things start\nwith one little move.").font(.system(size: 18, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                                Text("Pick from the library or add your own.").font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                            }.frame(maxWidth: .infinity).padding(.vertical, 30).rcSurface(padding: 0)
                        }
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                            routineExercise(exercise, index: index)
                        }
                        RCSecondaryButton(title: "Add exercises", icon: "plus") { showingLibrary = true }
                    }

                    if !exercises.isEmpty {
                        HStack {
                            Label("\(exercises.reduce(0) { $0 + $1.sets }) working sets", systemImage: "square.stack.3d.up")
                            Spacer()
                            Text("~\(Routine(name: name, exercises: exercises).estimatedMinutes) min")
                        }.font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                    }
                    if let error { Text(error).font(.system(size: 13)).foregroundStyle(.orange) }
                    RCPrimaryButton(title: routine == nil ? "Create routine" : "Save changes", icon: "checkmark") { saveRoutine() }
                        .disabled(!canSave).opacity(canSave ? 1 : 0.45)
                    if routine != nil {
                        Button("Delete routine", role: .destructive) { showingDelete = true }
                            .font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }.padding(20).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(RCTheme.text).background(RCTheme.background.ignoresSafeArea()).preferredColorScheme(RCAppearance.shared.colorScheme)
            .navigationTitle(routine == nil ? "New routine" : "Edit routine").navigationBarTitleDisplayModeIfAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if hasChanges { showingDiscard = true } else { dismiss() } }.foregroundStyle(RCTheme.muted)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .sheet(isPresented: $showingLibrary) {
                ExerciseLibraryView(existingNames: Set(exercises.map { $0.name.lowercased() })) { additions in exercises.append(contentsOf: additions) }
            }
            .confirmationDialog("Delete this routine?", isPresented: $showingDelete, titleVisibility: .visible) {
                Button("Delete routine", role: .destructive) { if let routine { store.deleteRoutine(id: routine.id) }; dismiss() }
            } message: { Text("Your completed workout history will stay in your log.") }
            .confirmationDialog("Discard your changes?", isPresented: $showingDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
        }
    }

    private func routineExercise(_ exercise: ExerciseTemplate, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.accentText)
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.name).font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(exercise.category).font(.system(size: 11)).foregroundStyle(RCTheme.muted)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Move up", systemImage: "arrow.up") { exercises.swapAt(index, index - 1) }.disabled(index == 0)
                    Button("Move down", systemImage: "arrow.down") { exercises.swapAt(index, index + 1) }.disabled(index == exercises.count - 1)
                    Button("Remove exercise", systemImage: "trash", role: .destructive) { exercises.removeAll { $0.id == exercise.id } }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16)).frame(width: 44, height: 44).foregroundStyle(RCTheme.muted)
                }.accessibilityLabel("Options for \(exercise.name)")
            }
            HStack(spacing: 12) {
                configurationPicker("SETS", value: exerciseBinding(id: exercise.id, keyPath: \.sets), values: Array(1...12))
                configurationPicker("REPS", value: exerciseBinding(id: exercise.id, keyPath: \.reps), values: Array(1...50))
                VStack(alignment: .leading, spacing: 5) {
                    FlowFieldLabel(title: "REST")
                    Picker("Rest between sets", selection: exerciseBinding(id: exercise.id, keyPath: \.restSeconds)) {
                        ForEach([0, 30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { Text($0 == 0 ? "None" : "\($0)s").tag($0) }
                    }.pickerStyle(.menu).labelsHidden().accessibilityLabel("Rest between sets")
                        .tint(RCTheme.text).frame(maxWidth: .infinity, minHeight: 44)
                        .background(RCTheme.background, in: RoundedRectangle(cornerRadius: 10))
                }.frame(maxWidth: .infinity)
            }
        }.padding(16).rcSurface(padding: 0)
    }

    private func configurationPicker(_ title: String, value: Binding<Int>, values: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            FlowFieldLabel(title: title)
            Picker(title.capitalized, selection: value) {
                ForEach(values, id: \.self) { Text("\($0)").tag($0) }
            }.pickerStyle(.menu).labelsHidden().accessibilityLabel(title.capitalized)
                .tint(RCTheme.text).frame(maxWidth: .infinity, minHeight: 44)
                .background(RCTheme.background, in: RoundedRectangle(cornerRadius: 10))
        }.frame(maxWidth: .infinity)
    }

    private func exerciseBinding(id: UUID, keyPath: WritableKeyPath<ExerciseTemplate, Int>) -> Binding<Int> {
        Binding(get: { exercises.first(where: { $0.id == id })?[keyPath: keyPath] ?? 1 }, set: { value in
            if let index = exercises.firstIndex(where: { $0.id == id }) { exercises[index][keyPath: keyPath] = value }
        })
    }

    private func saveRoutine() {
        let updated = Routine(id: routine?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), subtitle: routine?.subtitle ?? "Built for your rhythm", symbol: symbol, exercises: exercises)
        let saved = routine == nil ? store.addRoutine(updated) : store.updateRoutine(updated)
        if saved { dismiss() } else { error = "Add a routine name and at least one valid exercise." }
    }

    private func iconLabel(_ icon: String) -> String {
        switch icon {
        case "dumbbell.fill": "Dumbbell"
        case "bolt.fill": "Lightning"
        case "figure.strengthtraining.traditional": "Strength"
        case "figure.run": "Running"
        case "flame.fill": "Flame"
        default: "Sparkles"
        }
    }
}

private struct ExerciseLibraryView: View {
    let existingNames: Set<String>
    let onAdd: ([ExerciseTemplate]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var category = "All"
    @State private var selected: Set<UUID> = []
    @State private var showingCustom = false
    @State private var customName = ""
    @State private var customExercises: [ExerciseTemplate] = []

    private var library: [ExerciseTemplate] { WorkoutStore.exerciseLibrary + customExercises }
    private var categories: [String] { ["All"] + Array(Set(library.map(\.category))).sorted() }
    private var filtered: [ExerciseTemplate] {
        library.filter { (category == "All" || $0.category == category) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { item in
                            Button { category = item } label: {
                                Text(item).font(.system(size: 12, weight: .bold, design: .rounded)).padding(.horizontal, 16).frame(minHeight: 44)
                                    .foregroundStyle(category == item ? RCTheme.onAccent : RCTheme.muted)
                                    .background(category == item ? RCTheme.accent : RCTheme.card, in: Capsule())
                            }.buttonStyle(RCPressStyle())
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { exercise in libraryRow(exercise) }
                        if filtered.isEmpty {
                            RCEmptyState(symbol: "magnifyingglass", title: "Make room for your move.", message: "No matching exercises. Add a custom exercise below.")
                        }
                        Button { customName = search; showingCustom = true } label: {
                            Label("Create custom exercise", systemImage: "plus.circle").font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity, minHeight: 54)
                        }.buttonStyle(.plain).foregroundStyle(RCTheme.accentText).padding(.top, 10)
                    }.padding(.horizontal, 20).padding(.bottom, 18)
                }
                RCPrimaryButton(title: "Add \(selected.count) exercise\(selected.count == 1 ? "" : "s")", icon: "plus") {
                    let additions = library.filter { selected.contains($0.id) }.map {
                        ExerciseTemplate(name: $0.name, category: $0.category, sets: $0.sets, reps: $0.reps, restSeconds: $0.restSeconds)
                    }
                    onAdd(additions)
                    dismiss()
                }.disabled(selected.isEmpty).opacity(selected.isEmpty ? 0.45 : 1).padding(20)
            }
            .background(RCTheme.background.ignoresSafeArea()).preferredColorScheme(RCAppearance.shared.colorScheme)
            .navigationTitle("Exercise library").navigationBarTitleDisplayModeIfAvailable()
            .searchable(text: $search, prompt: "Find your next move")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(RCTheme.muted) } }
            .alert("Your own move", isPresented: $showingCustom) {
                TextField("Exercise name", text: $customName)
                Button("Add") {
                    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if let existing = library.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                        if !existingNames.contains(existing.name.lowercased()) { selected.insert(existing.id) }
                    } else {
                        let exercise = ExerciseTemplate(name: String(trimmed.prefix(80)), category: "Custom")
                        customExercises.append(exercise)
                        selected.insert(exercise.id)
                    }
                    category = "All"
                    search = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Give it a name. You can adjust sets and reps in your routine.") }
        }
    }

    private func libraryRow(_ exercise: ExerciseTemplate) -> some View {
        let alreadyAdded = existingNames.contains(exercise.name.lowercased())
        let isSelected = selected.contains(exercise.id)
        return Button {
            if isSelected { selected.remove(exercise.id) } else { selected.insert(exercise.id) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill").font(.system(size: 17)).foregroundStyle(RCTheme.muted).frame(width: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(RCTheme.text)
                    Text(alreadyAdded ? "Already in your routine" : exercise.category).font(.system(size: 11)).foregroundStyle(RCTheme.muted)
                }
                Spacer()
                Image(systemName: (isSelected || alreadyAdded) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(isSelected ? RCTheme.accent : RCTheme.muted)
            }.padding(16).frame(minHeight: 76).rcSurface(padding: 0)
        }.buttonStyle(RCPressStyle()).disabled(alreadyAdded).opacity(alreadyAdded ? 0.5 : 1)
            .accessibilityLabel("\(exercise.name), \(alreadyAdded ? "already added" : isSelected ? "selected" : "not selected")")
    }
}

struct FlowFieldLabel: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.8).foregroundStyle(RCTheme.muted)
    }
}

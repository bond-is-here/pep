import SwiftUI

struct WeightEntryView: View {
    var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var date = Date()
    @State private var error: String?
    @FocusState private var weightFocused: Bool

    private var exampleWeight: String {
        (store.unit == .kg ? 70.0 : 154.0).formatted(.number.precision(.fractionLength(1)).grouping(.never))
    }

    private var validationMessage: String? {
        guard !weight.isEmpty else { return nil }
        guard let value = FlowFormat.parseNumber(weight) else {
            return "Enter a number like \(exampleWeight). Use \(Locale.current.decimalSeparator ?? ".") for decimals, without spaces or thousands separators."
        }
        guard value > 0 else { return "Enter a weight greater than zero." }
        guard store.unit.kilograms(from: value) <= 1_000 else {
            return "Enter a weight up to \(FlowFormat.number(store.unit.value(fromKilograms: 1_000))) \(store.unit.symbol)."
        }
        return nil
    }

    private var validKilograms: Double? {
        guard let value = FlowFormat.parseNumber(weight) else { return nil }
        let kilograms = store.unit.kilograms(from: value)
        return kilograms > 0 && kilograms <= 1000 ? kilograms : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    RCHeader(title: "A little check-in.", subtitle: "Your body. Your pace. Always optional.")
                    if store.isReadOnly {
                        Label(store.persistenceError ?? "Your saved data is currently unavailable. You can add a check-in once Pep can open it again.", systemImage: "exclamationmark.triangle")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("weight.read-only")
                    }
                    VStack(spacing: 22) {
                        RCSymbolBadge(symbol: "scalemass.fill", color: RCTheme.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            TextField(exampleWeight, text: $weight)
                                .flowDecimalKeyboard().focused($weightFocused)
                                .font(.system(size: 62, weight: .bold, design: .rounded)).monospacedDigit()
                                .multilineTextAlignment(.center).textFieldStyle(.plain).frame(minWidth: 120, maxWidth: 215)
                                .minimumScaleFactor(0.65).accessibilityLabel("Body weight in \(store.unit.symbol)")
                                .onChange(of: weight) { _, _ in error = nil }
                                .disabled(store.isReadOnly).accessibilityIdentifier("weight.entry")
                            Text(store.unit.symbol).font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(RCTheme.muted)
                        }
                        Text("One small part of the picture").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(RCTheme.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 35).rcSurface(padding: 0)

                    if let validationMessage, !store.isReadOnly {
                        Text(validationMessage).font(.callout).foregroundStyle(RCTheme.accentText)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("weight.error")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        FlowFieldLabel(title: "CHECK-IN DATE")
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                            .tint(RCTheme.accentText).datePickerStyle(.compact).padding(16).rcSurface(padding: 0)
                            .disabled(store.isReadOnly).accessibilityIdentifier("weight.date")
                    }

                    if let previous = store.weights.sorted(by: { $0.date > $1.date }).first {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(RCTheme.muted)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Last check-in").font(.system(size: 12)).foregroundStyle(RCTheme.muted)
                                Text("\(FlowFormat.number(store.unit.value(fromKilograms: previous.kilograms))) \(store.unit.symbol) · \(previous.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            Spacer()
                        }
                    }
                    if let error {
                        Text(error).font(.callout).foregroundStyle(RCTheme.accentText)
                            .accessibilityIdentifier("weight.save-error")
                    }
                    RCPrimaryButton(title: "Save check-in", icon: "checkmark") {
                        guard let kilograms = validKilograms, store.addWeight(kilograms: kilograms, date: date) else {
                            error = store.persistenceError ?? "Enter a valid weight above zero."
                            return
                        }
                        weightFocused = false
                        dismiss()
                    }.disabled(validKilograms == nil || store.isReadOnly).opacity(validKilograms == nil || store.isReadOnly ? 0.45 : 1)
                        .accessibilityIdentifier("weight.save")
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "heart").foregroundStyle(RCTheme.accentText)
                        Text("Weight naturally changes from day to day. Your trend tells you more than a single check-in.")
                            .font(.system(size: 12)).foregroundStyle(RCTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }.padding(.horizontal, 3)
                }.padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(RCTheme.text).background(RCTheme.background.ignoresSafeArea()).preferredColorScheme(RCAppearance.shared.colorScheme)
            .navigationTitle("Log weight").navigationBarTitleDisplayModeIfAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(RCTheme.muted) }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }.accessibilityIdentifier("weight.keyboard-done")
                }
                #endif
            }
        }
    }
}

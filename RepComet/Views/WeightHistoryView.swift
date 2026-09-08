import SwiftUI

struct WeightHistoryView: View {
    let store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var showWeightEntry = false
    @State private var showDeleteConfirmation = false
    @State private var selectedEntry: WeightEntry?

    private var entries: [WeightEntry] { store.weights.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RCHeader(title: "Your check-ins.", subtitle: "A little record, on your terms.")
                    if entries.isEmpty {
                        RCEmptyState(symbol: "scalemass", title: "Whenever you're ready.", message: "Your weight check-ins will appear here. Start whenever it feels right.")
                            .rcSurface()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                    RCSecondaryButton(title: "Add a check-in", icon: "plus") { showWeightEntry = true }
                }.padding(22).padding(.bottom, 20)
            }
            .foregroundStyle(RCTheme.text).background(RCTheme.background.ignoresSafeArea()).preferredColorScheme(RCAppearance.shared.colorScheme)
            .navigationTitle("Weight history").navigationBarTitleDisplayModeIfAvailable()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(RCTheme.accentText)
                }
            }
            .sheet(isPresented: $showWeightEntry) { WeightEntryView(store: store) }
            .confirmationDialog("Delete this check-in?", isPresented: $showDeleteConfirmation, titleVisibility: .visible, presenting: selectedEntry) { entry in
                Button("Delete check-in", role: .destructive) { _ = store.deleteWeight(id: entry.id) }
                Button("Keep check-in", role: .cancel) {}
            } message: { entry in
                Text("Your \(FlowFormat.number(store.unit.value(fromKilograms: entry.kilograms))) \(store.unit.symbol) check-in from \(entry.date.formatted(date: .abbreviated, time: .omitted)) will be permanently removed.")
            }
        }
    }

    private func entryRow(_ entry: WeightEntry) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("\(FlowFormat.number(store.unit.value(fromKilograms: entry.kilograms))) \(store.unit.symbol)")
                    .font(.system(size: 23, weight: .bold, design: .rounded)).monospacedDigit()
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12)).foregroundStyle(RCTheme.muted)
            }
            Spacer(minLength: 0)
            Button {
                selectedEntry = entry
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash").font(.system(size: 16, weight: .medium))
                    .foregroundStyle(RCTheme.muted).frame(width: 44, height: 44)
                    .background(RCTheme.background, in: Circle())
            }.buttonStyle(RCPressStyle())
                .accessibilityLabel("Delete \(FlowFormat.number(store.unit.value(fromKilograms: entry.kilograms))) \(store.unit.symbol) check-in from \(entry.date.formatted(date: .abbreviated, time: .omitted))")
        }.rcSurface(padding: 18)
    }
}

import SwiftUI
import UniformTypeIdentifiers

private struct PepBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupView: View {
    let store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var document: PepBackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingData: Data?
    @State private var summary: WorkoutBackupSummary?
    @State private var confirmingRestore = false
    @State private var message: String?
    @State private var isError = false
    @State private var exportingRecovery = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RCHeader(title: "Your wins.\nPacked to go.", subtitle: "Keep a copy of everything you've put in.")
                    if store.isReadOnly, let error = store.persistenceError {
                        Label(error, systemImage: "lock.shield")
                            .font(.system(.subheadline, design: .rounded))
                    }
                    if store.hasRecoveryCopy {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Your original file is safe", systemImage: "doc.badge.clock")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Text("Pep kept a file it couldn't read. Save this untouched recovery copy for possible repair. It may need repair before it can be restored. If there are several copies, this saves the most recent one.")
                                .font(.system(.subheadline, design: .rounded)).foregroundStyle(RCTheme.muted)
                            RCSecondaryButton(title: "Save recovery copy", icon: "arrow.up.doc") {
                                do {
                                    document = PepBackupDocument(data: try store.exportRecoveryCopy())
                                    exportingRecovery = true
                                    exporting = true
                                } catch { report(error.localizedDescription, error: true) }
                            }.accessibilityIdentifier("backup.export-recovery")
                        }.rcSurface()
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Save a backup", systemImage: "square.and.arrow.up")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("Your routines, workouts, check-ins, unit, and weekly goal in one file. An in-progress workout is included, too.")
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(RCTheme.muted)
                        RCPrimaryButton(title: "Save to Files", icon: "arrow.up.doc") {
                            do {
                                document = PepBackupDocument(data: try store.exportBackup())
                                exportingRecovery = false
                                exporting = true
                            } catch { report(error.localizedDescription, error: true) }
                        }.disabled(store.isReadOnly).accessibilityIdentifier("backup.export")
                    }.rcSurface()

                    VStack(alignment: .leading, spacing: 16) {
                        Label("Bring your log back", systemImage: "square.and.arrow.down")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("Choose a Pep backup. You can review its contents before replacing this device's log. Save a copy of your current log first if you want to keep it.")
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(RCTheme.muted)
                        RCSecondaryButton(title: "Choose a backup", icon: "folder") { importing = true }
                            .disabled(store.activeSession != nil || store.isReadOnly)
                            .accessibilityIdentifier("backup.import")
                        if store.activeSession != nil {
                            Text("Finish or discard your current workout before restoring.")
                                .font(.system(.caption, design: .rounded)).foregroundStyle(RCTheme.muted)
                        }
                    }.rcSurface()
                    if let message {
                        Label(message, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(isError ? RCTheme.text : RCTheme.secondary)
                            .accessibilityIdentifier("backup.status")
                    }
                    Text("Backups contain your workout and weight history. Keep them somewhere you trust. Your colors and animation preferences stay on this device.")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(RCTheme.muted)
                }.padding(22)
            }
            .foregroundStyle(RCTheme.text).background(RCTheme.background.ignoresSafeArea())
            .navigationTitle("Backup & restore").navigationBarTitleDisplayModeIfAvailable()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                          defaultFilename: "Pep-\(exportingRecovery ? "recovery-copy" : "backup")-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                switch result {
                case .success: report(exportingRecovery ? "Recovery copy saved. Pep has kept the original, too." : "Backup saved.")
                case .failure(let error): report(error.localizedDescription, error: true)
                }
                document = nil
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom: url)
                    defer { try? file.close() }
                    var data = Data()
                    // Bound the actual read; cloud providers can omit file size.
                    while let chunk = try file.read(upToCount: min(65_536, WorkoutStore.maxBackupBytes + 1 - data.count)),
                          !chunk.isEmpty {
                        data.append(chunk)
                        guard data.count <= WorkoutStore.maxBackupBytes else { throw WorkoutBackupError.tooLarge }
                    }
                    summary = try store.backupSummary(data)
                    pendingData = data
                    confirmingRestore = true
                } catch { report(error.localizedDescription, error: true) }
            }
            .confirmationDialog("Replace this device's log?", isPresented: $confirmingRestore, titleVisibility: .visible) {
                Button("Replace with backup", role: .destructive) {
                    guard let pendingData else { return }
                    do {
                        try store.restoreBackup(pendingData)
                        report("Your log is back. Ready when you are.")
                    } catch { report(error.localizedDescription, error: true) }
                    self.pendingData = nil
                    summary = nil
                }
                Button("Cancel", role: .cancel) { pendingData = nil; summary = nil }
            } message: {
                if let summary {
                    Text("This backup contains \(summary.routineCount) routines, \(summary.sessionCount) workouts, and \(summary.weightCount) weight check-ins.\(summary.hasActiveWorkout ? " It also includes a workout to resume." : "") Your current log will be replaced.")
                }
            }
        }.preferredColorScheme(RCAppearance.shared.colorScheme).tint(RCTheme.accent)
    }

    private func report(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }
}

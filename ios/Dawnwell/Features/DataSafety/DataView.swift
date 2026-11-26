import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// "Your data": what is stored, a backup file to keep, and the local copies to go back to.
struct DataView: View {
    @Environment(\.modelContext) private var context
    @Query private var days: [DayLog]
    @Query private var weights: [WeightEntry]

    @State private var copies: [LocalCopies.Copy] = []
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pending: Pending?
    @State private var message: String?
    @State private var cloudAccount: CloudStatus.Account = .unknown
    @State private var shareUsage = Analytics.isUserEnabled()
    @State private var plus = PlusStore.shared
    @State private var csvFiles: [URL] = []
    @State private var paywall: Plus.Source?

    private struct Pending: Identifiable {
        let id = UUID()
        let title: String
        let snapshot: Snapshot
    }

    private var repo: Repository { Repository(context: context) }
    private let store = LocalCopies.standard

    var body: some View {
        let summary = repo.snapshot().summary
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.gap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("On this iPhone").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                    Text(summary).font(.system(size: 17, weight: .heavy)).foregroundStyle(Palette.ink)
                    Text(CloudStatus.message(storeSyncs: CloudStatus.storeSyncs, account: cloudAccount))
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup file").font(.system(size: 17, weight: .heavy))
                    Text("Save a file with all your logs to Files, iCloud Drive or email. Use it to move to a new phone.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    if let url = exportURL {
                        ShareLink(item: url) { Text("Save backup file") }
                            .buttonStyle(FilledButtonStyle())
                    }
                    Button("Restore from a file") { importing = true }
                        .buttonStyle(FilledButtonStyle(kind: .secondary))
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Spreadsheet").font(.system(size: 17, weight: .heavy))
                    Text("Your days, food, symptoms and doses as CSV files for Numbers, Excel or Google Sheets.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    if !plus.isPlus {
                        Button { paywall = .csvExport } label: { Label("Export CSV · Plus", systemImage: "lock.fill") }
                            .buttonStyle(FilledButtonStyle(kind: .secondary))
                            .accessibilityIdentifier("plus-csv")
                    } else if !csvFiles.isEmpty {
                        ShareLink(items: csvFiles) { Label("Export CSV", systemImage: "tablecells") }
                            .buttonStyle(FilledButtonStyle(kind: .secondary))
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Copies on this phone").font(.system(size: 17, weight: .heavy))
                    Text("Dawnwell keeps a copy each day for a week, and one before every restore.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    if copies.isEmpty {
                        Text("No copies yet. The first one is made the next time you open the app.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                    ForEach(copies) { c in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.takenAt.formatted(date: .abbreviated, time: .shortened)).fontWeight(.bold)
                                Text(c.reason.label).font(.footnote).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button("Restore") { askRestore(c) }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Palette.accentText)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .card()

                if Analytics.isAvailable {
                    Toggle(isOn: Binding(get: { shareUsage }, set: { shareUsage = $0; Analytics.setEnabled($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share anonymous usage").font(.system(size: 17, weight: .heavy))
                            Text("Counts like “finished setup” or “opened Plus”, with no name or account. Nothing you log is ever sent.")
                                .font(.footnote).foregroundStyle(Palette.muted)
                        }
                    }
                    .tint(Palette.accent)
                    .card()
                }

                if let message {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(Palette.sand)
                }
            }
            .padding(Metrics.gutter)
        }
        .background(Palette.bg)
        .navigationTitle("Your data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
        .onChange(of: plus.isPlus) { _, _ in refresh() }
        .sheet(item: $paywall) { PaywallView(source: $0) }
        .task { cloudAccount = await CloudStatus.account() }
        .task {
            // Design catalog (debug builds only): the restore question and the unreadable-file message.
            switch DesignFlags.alert {
            case "restore":
                try? await Task.sleep(for: .milliseconds(800))
                let date = Date().addingTimeInterval(-86_400).formatted(date: .abbreviated, time: .shortened)
                pending = Pending(title: String(localized: "Restore the copy from \(date)?"), snapshot: repo.snapshot())
            case "fileError":
                message = String(localized: "That file couldn't be opened.")
            default:
                break
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): readFile(url)
            case .failure: message = String(localized: "That file couldn't be opened.")
            }
        }
        .confirmationDialog(pending?.title ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible, presenting: pending) { p in
            Button("Replace my data") { restore(p.snapshot) }
            Button("Cancel", role: .cancel) {}
        } message: { p in
            let summary = p.snapshot.summary
            Text("This brings back \(summary). Your current data is copied first, so you can go back.")
        }
    }

    private func refresh() {
        copies = store.list()
        exportURL = try? DataSafety.exportFile(repo: repo)
        csvFiles = plus.isPlus ? ((try? CSVExport.write(CSVExport.make(from: repo.snapshot()))) ?? []) : []
    }

    private func askRestore(_ c: LocalCopies.Copy) {
        do {
            let date = c.takenAt.formatted(date: .abbreviated, time: .shortened)
            pending = Pending(title: String(localized: "Restore the copy from \(date)?"), snapshot: try store.read(c))
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? String(localized: "This copy can't be read.")
        }
    }

    private func readFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let file = try BackupFile.decode(Data(contentsOf: url))
            let date = file.exportedAt.formatted(date: .abbreviated, time: .omitted)
            pending = Pending(title: String(localized: "Restore the backup from \(date)?"), snapshot: file.data)
        } catch let e as BackupFile.ReadError {
            message = e.errorDescription
        } catch {
            message = String(localized: "That file couldn't be opened.")
        }
    }

    private func restore(_ s: Snapshot) {
        do {
            try DataSafety.restore(s, repo: repo, copies: store)
            message = String(localized: "Done. Your data was restored, and the data you had before is kept as a copy.")
        } catch {
            message = String(localized: "Nothing was changed. Your data could not be copied first, so it was left as it is.")
        }
        refresh()
    }
}

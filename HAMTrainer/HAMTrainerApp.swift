import SwiftUI

@main
struct HAMTrainerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("HAM Trainer") {
            SnapshotRootView()
                .environmentObject(store)
                .frame(minWidth: 860, minHeight: 620)
                .alert("HAM Trainer", isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                )) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandMenu("Учёба") {
                Button("Умная сессия") { NotificationCenter.default.post(name: .startSmartStudy, object: nil) }
                    .keyboardShortcut("s", modifiers: [.command])
                Button("Поиск") { NotificationCenter.default.post(name: .openSearch, object: nil) }
                    .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
}

struct SnapshotRootView: View {
    @EnvironmentObject private var store: AppStore
    private var snapshotQuestion: Question? {
        guard let index = CommandLine.arguments.firstIndex(of: "--snapshot-question"), CommandLine.arguments.indices.contains(index + 1), let number = Int(CommandLine.arguments[index + 1]) else { return nil }
        return store.questions.first(where: { $0.examNumber == number })
    }
    private var snapshotGlossary: GlossaryEntry? {
        guard let index = CommandLine.arguments.firstIndex(of: "--snapshot-glossary"), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return store.glossary.first(where: { $0.id == CommandLine.arguments[index + 1] })
    }
    private var snapshotColorScheme: ColorScheme? {
        guard CommandLine.arguments.contains("--snapshot") else { return nil }
        guard let index = CommandLine.arguments.firstIndex(of: "--appearance"), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1] == "dark" ? .dark : .light
    }
    var body: some View {
        Group {
            if let snapshotQuestion { QuestionDetailView(question: snapshotQuestion) }
            else if let snapshotGlossary { GlossaryCard(entry: snapshotGlossary) }
            else { MainView() }
        }.preferredColorScheme(snapshotColorScheme).background(SnapshotCaptureView())
    }
}

extension Notification.Name {
    static let startSmartStudy = Notification.Name("startSmartStudy")
    static let openSearch = Notification.Name("openSearch")
}

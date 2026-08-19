import AppKit
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard, smart, weak, topics, mock, all, glossary, statistics, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: "Обзор"
        case .smart: "Умная учёба"
        case .weak: "Слабые вопросы"
        case .topics: "Темы"
        case .mock: "Пробный экзамен"
        case .all: "Все вопросы"
        case .glossary: "Словарь"
        case .statistics: "Статистика"
        case .settings: "Настройки"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .smart: "sparkles"
        case .weak: "waveform.path.ecg"
        case .topics: "books.vertical"
        case .mock: "checklist"
        case .all: "list.number"
        case .glossary: "character.book.closed"
        case .statistics: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var store: AppStore
    @State private var section: AppSection? = .dashboard

    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--section"), CommandLine.arguments.indices.contains(index + 1), let value = AppSection(rawValue: CommandLine.arguments[index + 1]) {
            _section = State(initialValue: value)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationTitle("HAM Trainer")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            Group {
                switch section ?? .dashboard {
                case .dashboard: DashboardView(section: $section)
                case .smart: SmartStudyView()
                case .weak: WeakQuestionsView()
                case .topics: TopicsView()
                case .mock: MockExamView()
                case .all: QuestionBrowserView()
                case .glossary: GlossaryView()
                case .statistics: StatisticsView()
                case .settings: SettingsView()
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onReceive(NotificationCenter.default.publisher(for: .startSmartStudy)) { _ in section = .smart }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in section = .all }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var section: AppSection?

    private func count(_ state: LearningState) -> Int { store.progress.values.count(where: { $0.state == state }) }
    private var unseen: Int { store.questions.count - store.progress.values.count(where: { $0.state != .unseen }) }
    private var due: Int { store.progress.values.count(where: { ($0.nextDueAt ?? .distantFuture) <= Date() && $0.state != .mastered }) }
    private var accuracy: Int {
        let attempts = store.progress.values.reduce(0) { $0 + $1.correctCount + $1.incorrectCount + $1.dontKnowCount + $1.revealedCount }
        let correct = store.progress.values.reduce(0) { $0 + $1.correctCount }
        return attempts == 0 ? 0 : Int((Double(correct) / Double(attempts) * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Добро пожаловать").font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Спокойная подготовка к экзамену второй категории").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Начать умную сессию") { section = .smart }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    StatCard(title: "Освоено", value: count(.mastered), icon: "checkmark.seal.fill", tint: .green)
                    StatCard(title: "Повторить сегодня", value: due, icon: "calendar.badge.clock", tint: .orange)
                    StatCard(title: "Слабые", value: count(.weak), icon: "waveform.path.ecg", tint: .red)
                    StatCard(title: "Не изучены", value: unseen, icon: "circle.dashed", tint: .blue)
                    StatCard(title: "Точность", value: accuracy, suffix: "%", icon: "scope", tint: .purple)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { Text("Путь к готовности").font(.headline); Spacer(); Text("\(count(.mastered)) / 405").monospacedDigit().foregroundStyle(.secondary) }
                        ProgressView(value: Double(count(.mastered)), total: 405).tint(.accentColor)
                        Text("Освоенным вопрос становится только после нескольких успешных повторений, разделённых во времени.")
                            .font(.callout).foregroundStyle(.secondary)
                    }.padding(8)
                }

                WeakTopicsPanel()
            }.padding(30).frame(maxWidth: 1100, alignment: .leading)
        }.navigationTitle("Обзор")
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    var suffix = ""
    let icon: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
            Text("\(value)\(suffix)").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
            Text(title).font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }
}

struct WeakTopicsPanel: View {
    @EnvironmentObject private var store: AppStore
    private var topics: [(String, Int)] {
        Dictionary(grouping: store.questions.filter { store.progressFor($0).state == .weak }, by: \.topic)
            .map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }.prefix(5).map { $0 }
    }
    var body: some View {
        GroupBox("Темы, которым нужна помощь") {
            if topics.isEmpty {
                ContentUnavailableView("Пока нет слабых тем", systemImage: "leaf", description: Text("После первых ответов здесь появятся полезные подсказки."))
                    .frame(height: 150)
            } else {
                VStack(spacing: 12) {
                    ForEach(topics, id: \.0) { topic, count in
                        HStack { Text(topic); Spacer(); Text("\(count)").monospacedDigit().foregroundStyle(.secondary) }
                    }
                }.padding(8)
            }
        }
    }
}

struct WeakQuestionsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var session: StudySession?
    private var weak: [Question] { store.questions.filter { let p = store.progressFor($0); return p.state == .weak || p.manuallyMarkedHard } }
    var body: some View {
        Group {
            if let session { StudyRunnerView(session: session, onFinish: { self.session = nil }) }
            else if weak.isEmpty { ContentUnavailableView("Слабых вопросов пока нет", systemImage: "checkmark.circle", description: Text("Они появятся после ошибок, «Не знаю» или ручной отметки.")) }
            else {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Слабые вопросы").font(.largeTitle.bold())
                    Text("Отдельная тренировка может повторять трудные вопросы чаще. В обычной сессии действует строгий лимит повторов.").foregroundStyle(.secondary)
                    Button("Тренировать \(weak.count) вопросов") { session = StudySession(questions: weak, drillWeak: true) }.buttonStyle(.borderedProminent)
                    List(weak) { q in QuestionRow(question: q) }
                }.padding(28)
            }
        }.navigationTitle("Слабые вопросы")
    }
}

struct TopicsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTopic: String?
    @State private var session: StudySession?
    private var topics: [(String, [Question])] { Dictionary(grouping: store.questions, by: \.topic).sorted { $0.key < $1.key } }
    var body: some View {
        Group {
            if let session { StudyRunnerView(session: session, onFinish: { self.session = nil }) }
            else {
                List(topics, id: \.0, selection: $selectedTopic) { topic, questions in
                    HStack {
                        VStack(alignment: .leading) { Text(topic).font(.headline); Text("\(questions.count) вопросов").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Учить") { session = StudySession(questions: questions) }.buttonStyle(.borderless)
                    }.padding(.vertical, 5)
                }.navigationTitle("Темы")
            }
        }
    }
}

struct QuestionRow: View {
    @EnvironmentObject private var store: AppStore
    let question: Question
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("№ \(question.examNumber)").font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) { Text(question.stem).lineLimit(2); Text(question.topic).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Text(store.progressFor(question).state.title).font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(.quaternary, in: Capsule())
        }.padding(.vertical, 4)
    }
}

struct QuestionBrowserView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var stateFilter: LearningState?
    @State private var selected: Question?
    @FocusState private var searchFocused: Bool
    private var filtered: [Question] {
        store.questions.filter { question in
            let stateOK = stateFilter == nil || store.progressFor(question).state == stateFilter
            guard stateOK, !query.isEmpty else { return stateOK }
            let content = "\(question.examNumber) \(question.stem) \(question.options.map(\.text).joined(separator: " ")) \(question.explanationShort) \(question.topic)"
            return content.localizedCaseInsensitiveContains(query)
        }
    }
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    TextField("Вопрос, ответ, тема или термин", text: $query).textFieldStyle(.roundedBorder).focused($searchFocused)
                    Picker("Состояние", selection: $stateFilter) {
                        Text("Все").tag(LearningState?.none)
                        ForEach(LearningState.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                    }.labelsHidden().frame(width: 140)
                }.padding()
                List(filtered, selection: $selected) { q in QuestionRow(question: q).tag(q) }
            }.navigationTitle("Все вопросы — \(filtered.count)")
        } detail: {
            if let selected { QuestionDetailView(question: selected) }
            else { ContentUnavailableView("Выберите вопрос", systemImage: "list.number") }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in searchFocused = true }
    }
}

struct QuestionDetailView: View {
    @EnvironmentObject private var store: AppStore
    let question: Question
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Вопрос № \(question.examNumber)").font(.title2.bold())
                Text(question.topic).font(.callout).foregroundStyle(.secondary)
                Text(question.stem).font(.title3)
                FigureView(asset: question.figureAsset)
                ForEach(question.options) { option in
                    HStack { Image(systemName: option.id == question.correctOptionId ? "checkmark.circle.fill" : "circle").foregroundStyle(option.id == question.correctOptionId ? .green : .secondary); Text(option.text) }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                ExplanationView(question: question)
                SourceView(question: question)
            }.padding(28).frame(maxWidth: 850, alignment: .leading)
        }.background(Color(nsColor: .windowBackgroundColor))
    }
}

struct GlossaryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    var entries: [GlossaryEntry] { store.glossary.filter { query.isEmpty || "\($0.term) \($0.aliases.joined(separator: " ")) \($0.shortDefinition)".localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(spacing: 0) {
            TextField("Найти термин", text: $query).textFieldStyle(.roundedBorder).padding()
            List(entries) { entry in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(entry.fromZero)
                        Label(entry.radioExample, systemImage: "radio").foregroundStyle(.secondary)
                        Button("Я не понимаю этот термин") { store.markConceptWeak(entry.id) }
                    }.padding(.vertical, 8)
                } label: {
                    VStack(alignment: .leading, spacing: 3) { Text(entry.term).font(.headline); Text(entry.shortDefinition).font(.callout).foregroundStyle(.secondary) }
                }.padding(.vertical, 5)
            }
        }.navigationTitle("Словарь — \(entries.count)")
    }
}

struct StatisticsView: View {
    @EnvironmentObject private var store: AppStore
    private var mostLapses: [(Question, Int)] {
        store.questions.map { ($0, store.progressFor($0).lapseCount) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(10).map { $0 }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Статистика").font(.largeTitle.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))]) {
                    StatCard(title: "Всего попыток", value: store.progress.values.reduce(0) { $0 + $1.attempts }, icon: "cursorarrow.click", tint: .blue)
                    StatCard(title: "Не знаю", value: store.progress.values.reduce(0) { $0 + $1.dontKnowCount }, icon: "questionmark", tint: .orange)
                    StatCard(title: "Пробные экзамены", value: store.mockScores.count, icon: "checklist", tint: .purple)
                }
                GroupBox("Больше всего ошибок") {
                    if mostLapses.isEmpty { Text("Данные появятся после повторений.").foregroundStyle(.secondary).padding() }
                    else { ForEach(mostLapses, id: \.0.id) { q, count in HStack { Text("№ \(q.examNumber)  \(q.stem)").lineLimit(1); Spacer(); Text("\(count)").monospacedDigit() }.padding(.vertical, 4) } }
                }
                GroupBox("Результаты пробных экзаменов") {
                    if store.mockScores.isEmpty { Text("Экзамены ещё не проходились.").foregroundStyle(.secondary).padding() }
                    else { ForEach(store.mockScores.reversed()) { score in HStack { Text(score.date.formatted(date: .abbreviated, time: .shortened)); Spacer(); Text("\(score.correct)/30").bold().foregroundStyle(score.passed ? .green : .red) }.padding(.vertical, 4) } }
                }
            }.padding(28).frame(maxWidth: 1000, alignment: .leading)
        }.navigationTitle("Статистика")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showReset = false
    var body: some View {
        Form {
            Section("Учёба") {
                Picker("Длина сессии", selection: $store.settings.defaultSessionLength) { ForEach([10, 20, 30, 40], id: \.self) { Text("\($0)").tag($0) } }
                Toggle("Перемешивать варианты ответов", isOn: $store.settings.randomizeOptions)
                Toggle("Звуковые эффекты", isOn: $store.settings.soundEffects)
                Picker("Объяснение", selection: $store.settings.explanationStyle) { Text("Кратко").tag("Кратко"); Text("С нуля").tag("С нуля"); Text("Подробно").tag("Подробно") }
            }
            Section("Резервная копия") {
                HStack { Button("Экспорт JSON…", action: exportBackup); Button("Импорт JSON…", action: importBackup); Spacer() }
                Text("Прогресс автоматически сохраняется после каждого ответа в Application Support/HAMTrainer.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Данные") {
                Button("Сбросить весь прогресс…", role: .destructive) { showReset = true }
            }
            Section("Источник") {
                LabeledContent("Банк", value: "405 вопросов, вторая категория")
                LabeledContent("Версия схемы данных", value: "1")
                Text("Официальный ответ банка и примечание для реальной практики хранятся отдельно.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).navigationTitle("Настройки")
            .onChange(of: store.settings) { _, _ in store.saveProgress() }
            .confirmationDialog("Удалить весь учебный прогресс?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Удалить прогресс", role: .destructive) { store.resetProgress() }
                Button("Отмена", role: .cancel) {}
            } message: { Text("Банк вопросов останется на месте. Перед сбросом можно экспортировать JSON.") }
    }

    private func exportBackup() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "HAMTrainer-backup.json"; panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url { do { try store.exportBackup(to: url) } catch { store.errorMessage = error.localizedDescription } }
    }
    private func importBackup() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { do { try store.importBackup(from: url) } catch { store.errorMessage = error.localizedDescription } }
    }
}

struct SourceView: View {
    let question: Question
    var body: some View {
        GroupBox("Источник") {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(question.sourceReference.document), стр. \(question.sourceReference.page), вопрос № \(question.sourceReference.sourceQuestionNumber)")
                Text("Пояснение: \(question.sourceReference.explanationDocument), стр. \(question.sourceReference.explanationPage)")
                if let note = question.legalHistoricalNote { Label(note, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).padding(.top, 6) }
            }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(5)
        }
    }
}

struct FigureView: View {
    let asset: String?
    var body: some View {
        if let asset, let url = Bundle.studyResources.url(forResource: asset, withExtension: nil, subdirectory: "Content"), let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 520).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
    }
}

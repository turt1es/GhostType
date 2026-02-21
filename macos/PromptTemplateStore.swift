import Foundation

enum PromptLibraryMarkdownParser {
    struct ParsedDocument {
        let standardAskPrompt: String
        let standardTranslatePrompt: String
        let standardGeminiASRPrompt: String
        let dictationPrompts: [String: String]
    }

    private static let askHeading = "Standard Ask System Prompt"
    private static let translateHeading = "Standard Translate System Prompt"
    private static let geminiHeading = "Standard Multimodal AI Model Prompt"

    static func parse(markdown: String) -> ParsedDocument? {
        let lines = markdown.components(separatedBy: .newlines)
        var index = 0
        var currentHeading: String?
        var codeBlockByHeading: [String: String] = [:]

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("### ") {
                let heading = String(trimmed.dropFirst(4))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentHeading = heading.isEmpty ? nil : heading
                index += 1
                continue
            }

            if trimmed.hasPrefix("```"), let heading = currentHeading {
                index += 1
                var blockLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index]
                    if candidate.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                        break
                    }
                    blockLines.append(candidate)
                    index += 1
                }
                let block = blockLines
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !block.isEmpty {
                    codeBlockByHeading[heading] = block
                }
            }

            index += 1
        }

        guard let askPrompt = codeBlockByHeading[askHeading],
              let translatePrompt = codeBlockByHeading[translateHeading],
              let geminiPrompt = codeBlockByHeading[geminiHeading]
        else {
            return nil
        }

        var dictationPrompts: [String: String] = [:]
        for (heading, block) in codeBlockByHeading {
            if heading == askHeading || heading == translateHeading || heading == geminiHeading {
                continue
            }
            dictationPrompts[heading] = block
        }

        return ParsedDocument(
            standardAskPrompt: askPrompt,
            standardTranslatePrompt: translatePrompt,
            standardGeminiASRPrompt: geminiPrompt,
            dictationPrompts: dictationPrompts
        )
    }
}

enum PromptLengthMode: String, CaseIterable, Identifiable, Codable {
    case long
    case short

    var id: String { rawValue }
}

enum PromptTemplateCompressor {
    private static let exampleMarkers: [String] = [
        "example",
        "few-shot",
        "few shot",
        "示例",
        "user:",
        "assistant:",
        "input:",
        "output:",
        "reference text:",
        "voice question:",
        "target:",
    ]

    static func compress(_ prompt: String, fallback: String) -> String {
        let source = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lines = source.components(separatedBy: .newlines)
        var kept: [String] = []
        kept.reserveCapacity(14)

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }
            if line.hasPrefix("```") || line.hasPrefix("---") {
                continue
            }
            let lowered = line.lowercased()
            if exampleMarkers.contains(where: { lowered.contains($0) }) {
                continue
            }
            kept.append(line)
            if kept.count >= 12 {
                break
            }
        }

        let compressed = kept.joined(separator: "\n")
        let candidate = compressed.isEmpty ? source : compressed
        let limited = String(candidate.prefix(900))
        let cleaned = limited.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }
}

struct PromptPreset: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var dictateSystemPrompt: String
    var shortDictateSystemPrompt: String
    var askSystemPrompt: String
    var shortAskSystemPrompt: String
    var translateSystemPrompt: String
    var shortTranslateSystemPrompt: String
    var geminiASRPrompt: String
    var shortGeminiASRPrompt: String
    var isBuiltIn: Bool
    var updatedAt: Date

    init(
        id: String,
        name: String,
        dictateSystemPrompt: String,
        shortDictateSystemPrompt: String? = nil,
        askSystemPrompt: String,
        shortAskSystemPrompt: String? = nil,
        translateSystemPrompt: String,
        shortTranslateSystemPrompt: String? = nil,
        geminiASRPrompt: String,
        shortGeminiASRPrompt: String? = nil,
        isBuiltIn: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dictateSystemPrompt = dictateSystemPrompt
        self.shortDictateSystemPrompt = PromptTemplateCompressor.compress(
            shortDictateSystemPrompt ?? dictateSystemPrompt,
            fallback: dictateSystemPrompt
        )
        self.askSystemPrompt = askSystemPrompt
        self.shortAskSystemPrompt = PromptTemplateCompressor.compress(
            shortAskSystemPrompt ?? askSystemPrompt,
            fallback: askSystemPrompt
        )
        self.translateSystemPrompt = translateSystemPrompt
        self.shortTranslateSystemPrompt = PromptTemplateCompressor.compress(
            shortTranslateSystemPrompt ?? translateSystemPrompt,
            fallback: translateSystemPrompt
        )
        self.geminiASRPrompt = geminiASRPrompt
        self.shortGeminiASRPrompt = PromptTemplateCompressor.compress(
            shortGeminiASRPrompt ?? geminiASRPrompt,
            fallback: geminiASRPrompt
        )
        self.isBuiltIn = isBuiltIn
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case dictateSystemPrompt
        case shortDictateSystemPrompt
        case askSystemPrompt
        case shortAskSystemPrompt
        case translateSystemPrompt
        case shortTranslateSystemPrompt
        case geminiASRPrompt
        case shortGeminiASRPrompt
        case isBuiltIn
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dictateSystemPrompt = try container.decode(String.self, forKey: .dictateSystemPrompt)
        shortDictateSystemPrompt = PromptTemplateCompressor.compress(
            try container.decodeIfPresent(String.self, forKey: .shortDictateSystemPrompt) ?? dictateSystemPrompt,
            fallback: dictateSystemPrompt
        )
        askSystemPrompt = try container.decode(String.self, forKey: .askSystemPrompt)
        shortAskSystemPrompt = PromptTemplateCompressor.compress(
            try container.decodeIfPresent(String.self, forKey: .shortAskSystemPrompt) ?? askSystemPrompt,
            fallback: askSystemPrompt
        )
        translateSystemPrompt = try container.decode(String.self, forKey: .translateSystemPrompt)
        shortTranslateSystemPrompt = PromptTemplateCompressor.compress(
            try container.decodeIfPresent(String.self, forKey: .shortTranslateSystemPrompt) ?? translateSystemPrompt,
            fallback: translateSystemPrompt
        )
        geminiASRPrompt = try container.decode(String.self, forKey: .geminiASRPrompt)
        shortGeminiASRPrompt = PromptTemplateCompressor.compress(
            try container.decodeIfPresent(String.self, forKey: .shortGeminiASRPrompt) ?? geminiASRPrompt,
            fallback: geminiASRPrompt
        )
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

@MainActor
final class PromptTemplateStore: ObservableObject {
    private enum Keys {
        static let selectedPromptPresetID = "GhostType.selectedPromptPresetID"
        static let customPromptPresets = "GhostType.customPromptPresets"
        static let dictateSystemPromptTemplate = "GhostType.dictateSystemPromptTemplate"
        static let shortDictateSystemPromptTemplate = "GhostType.shortDictateSystemPromptTemplate"
        static let askSystemPromptTemplate = "GhostType.askSystemPromptTemplate"
        static let shortAskSystemPromptTemplate = "GhostType.shortAskSystemPromptTemplate"
        static let translateSystemPromptTemplate = "GhostType.translateSystemPromptTemplate"
        static let shortTranslateSystemPromptTemplate = "GhostType.shortTranslateSystemPromptTemplate"
        static let geminiASRPromptTemplate = "GhostType.geminiASRPromptTemplate"
        static let shortGeminiASRPromptTemplate = "GhostType.shortGeminiASRPromptTemplate"
        static let promptLengthMode = "GhostType.promptLengthMode"
        static let autoPromptLengthSwitchingEnabled = "GhostType.autoPromptLengthSwitchingEnabled"
        static let promptTemplateVersion = "GhostType.promptTemplateVersion"
        static let contextDefaultDictationPresetID = "GhostType.contextDefaultDictationPresetID"
        static let contextActiveDictationPresetID = "GhostType.contextActiveDictationPresetID"
        static let contextRoutingRules = "GhostType.contextRoutingRules"
    }

    static let currentPromptTemplateVersion = 5
    static let legacyDefaultPromptPresetIDs: Set<String> = [
        "builtin.strict",
        "builtin.precise-english-v2",
    ]

    private let defaults: UserDefaults

    @Published var selectedPromptPresetID: String {
        didSet {
            defaults.set(selectedPromptPresetID, forKey: Keys.selectedPromptPresetID)
        }
    }

    @Published var customPromptPresets: [PromptPreset] {
        didSet {
            persistCustomPromptPresets()
        }
    }

    @Published var dictateSystemPromptTemplate: String {
        didSet {
            defaults.set(dictateSystemPromptTemplate, forKey: Keys.dictateSystemPromptTemplate)
        }
    }

    @Published var shortDictateSystemPromptTemplate: String {
        didSet {
            defaults.set(shortDictateSystemPromptTemplate, forKey: Keys.shortDictateSystemPromptTemplate)
        }
    }

    @Published var askSystemPromptTemplate: String {
        didSet {
            defaults.set(askSystemPromptTemplate, forKey: Keys.askSystemPromptTemplate)
        }
    }

    @Published var shortAskSystemPromptTemplate: String {
        didSet {
            defaults.set(shortAskSystemPromptTemplate, forKey: Keys.shortAskSystemPromptTemplate)
        }
    }

    @Published var translateSystemPromptTemplate: String {
        didSet {
            defaults.set(translateSystemPromptTemplate, forKey: Keys.translateSystemPromptTemplate)
        }
    }

    @Published var shortTranslateSystemPromptTemplate: String {
        didSet {
            defaults.set(shortTranslateSystemPromptTemplate, forKey: Keys.shortTranslateSystemPromptTemplate)
        }
    }

    @Published var geminiASRPromptTemplate: String {
        didSet {
            defaults.set(geminiASRPromptTemplate, forKey: Keys.geminiASRPromptTemplate)
        }
    }

    @Published var shortGeminiASRPromptTemplate: String {
        didSet {
            defaults.set(shortGeminiASRPromptTemplate, forKey: Keys.shortGeminiASRPromptTemplate)
        }
    }

    @Published var promptLengthMode: PromptLengthMode {
        didSet {
            defaults.set(promptLengthMode.rawValue, forKey: Keys.promptLengthMode)
        }
    }

    @Published var autoPromptLengthSwitchingEnabled: Bool {
        didSet {
            defaults.set(autoPromptLengthSwitchingEnabled, forKey: Keys.autoPromptLengthSwitchingEnabled)
            if autoPromptLengthSwitchingEnabled {
                applyAutoPromptLength(for: currentLLMEngineOption())
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let loadedCustomPromptPresetsRaw = Self.loadCustomPromptPresets(from: defaults)
        let legacyCleanup = PromptPresetMigration.removeLegacyContextPromptPresets(from: loadedCustomPromptPresetsRaw)
        let loadedCustomPromptPresets = legacyCleanup.presets
        if loadedCustomPromptPresets != loadedCustomPromptPresetsRaw {
            Self.persistCustomPromptPresets(loadedCustomPromptPresets, to: defaults)
        }
        PromptPresetMigration.migrateContextPresetReferences(
            in: defaults,
            customPresetReplacementMap: legacyCleanup.replacementMap
        )

        let loadedSelectedPromptPresetIDRaw = defaults.string(forKey: Keys.selectedPromptPresetID)
        let loadedSelectedPromptPresetID = {
            guard let storedID = loadedSelectedPromptPresetIDRaw else {
                return Self.defaultPromptPreset.id
            }
            let migrated = legacyCleanup.replacementMap[storedID]
                ?? PromptPresetMigration.migratedLegacyPresetID(storedID)
                ?? storedID
            if Self.legacyDefaultPromptPresetIDs.contains(migrated) {
                return Self.defaultPromptPreset.id
            }
            return migrated
        }()
        if let raw = loadedSelectedPromptPresetIDRaw,
           raw != loadedSelectedPromptPresetID {
            defaults.set(loadedSelectedPromptPresetID, forKey: Keys.selectedPromptPresetID)
        }

        customPromptPresets = loadedCustomPromptPresets
        selectedPromptPresetID = loadedSelectedPromptPresetID

        let promptTemplateVersion = defaults.integer(forKey: Keys.promptTemplateVersion)
        let selectedPresetIsCustom = loadedCustomPromptPresets.contains(where: { $0.id == loadedSelectedPromptPresetID })
        let shouldMigrateBuiltInPromptTemplates = promptTemplateVersion < Self.currentPromptTemplateVersion && !selectedPresetIsCustom
        if shouldMigrateBuiltInPromptTemplates {
            defaults.removeObject(forKey: Keys.dictateSystemPromptTemplate)
            defaults.removeObject(forKey: Keys.shortDictateSystemPromptTemplate)
            defaults.removeObject(forKey: Keys.askSystemPromptTemplate)
            defaults.removeObject(forKey: Keys.shortAskSystemPromptTemplate)
            defaults.removeObject(forKey: Keys.translateSystemPromptTemplate)
            defaults.removeObject(forKey: Keys.shortTranslateSystemPromptTemplate)
            defaults.removeObject(forKey: Keys.geminiASRPromptTemplate)
            defaults.removeObject(forKey: Keys.shortGeminiASRPromptTemplate)
        }

        let initialPreset = Self.promptPreset(by: loadedSelectedPromptPresetID, customPresets: loadedCustomPromptPresets)
            ?? Self.defaultPromptPreset
        dictateSystemPromptTemplate = defaults.string(forKey: Keys.dictateSystemPromptTemplate) ?? initialPreset.dictateSystemPrompt
        shortDictateSystemPromptTemplate = defaults.string(forKey: Keys.shortDictateSystemPromptTemplate)
            ?? initialPreset.shortDictateSystemPrompt
        askSystemPromptTemplate = defaults.string(forKey: Keys.askSystemPromptTemplate) ?? initialPreset.askSystemPrompt
        shortAskSystemPromptTemplate = defaults.string(forKey: Keys.shortAskSystemPromptTemplate)
            ?? initialPreset.shortAskSystemPrompt
        translateSystemPromptTemplate = defaults.string(forKey: Keys.translateSystemPromptTemplate) ?? initialPreset.translateSystemPrompt
        shortTranslateSystemPromptTemplate = defaults.string(forKey: Keys.shortTranslateSystemPromptTemplate)
            ?? initialPreset.shortTranslateSystemPrompt
        geminiASRPromptTemplate = defaults.string(forKey: Keys.geminiASRPromptTemplate) ?? initialPreset.geminiASRPrompt
        shortGeminiASRPromptTemplate = defaults.string(forKey: Keys.shortGeminiASRPromptTemplate)
            ?? initialPreset.shortGeminiASRPrompt
        promptLengthMode = PromptLengthMode(
            rawValue: defaults.string(forKey: Keys.promptLengthMode) ?? PromptLengthMode.long.rawValue
        ) ?? .long
        autoPromptLengthSwitchingEnabled = defaults.object(forKey: Keys.autoPromptLengthSwitchingEnabled) as? Bool ?? true

        if Self.promptPreset(by: loadedSelectedPromptPresetID, customPresets: loadedCustomPromptPresets) == nil {
            selectedPromptPresetID = Self.defaultPromptPreset.id
        }
        defaults.set(Self.currentPromptTemplateVersion, forKey: Keys.promptTemplateVersion)
        PromptPresetMigration.migrate(self)
    }

    var availablePromptPresets: [PromptPreset] {
        Self.builtInPromptPresets + customPromptPresets
    }

    var selectedPromptPresetName: String {
        availablePromptPresets.first(where: { $0.id == selectedPromptPresetID })?.name ?? Self.defaultPromptPreset.name
    }

    var isSelectedPromptPresetCustom: Bool {
        customPromptPresets.contains(where: { $0.id == selectedPromptPresetID })
    }

    func promptPreset(by id: String) -> PromptPreset? {
        Self.promptPreset(by: id, customPresets: customPromptPresets)
    }

    func normalizedPromptPresetID(_ rawID: String?, fallbackID: String? = nil) -> String {
        let fallback = fallbackID ?? Self.defaultPromptPreset.id
        let trimmed = (rawID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        let candidate = PromptPresetMigration.migratedLegacyPresetID(trimmed) ?? trimmed
        return promptPreset(by: candidate) == nil ? fallback : candidate
    }

    func applyPromptPreset(id: String) {
        guard let preset = Self.promptPreset(by: id, customPresets: customPromptPresets) else { return }
        selectedPromptPresetID = preset.id
        dictateSystemPromptTemplate = preset.dictateSystemPrompt
        shortDictateSystemPromptTemplate = preset.shortDictateSystemPrompt
        askSystemPromptTemplate = preset.askSystemPrompt
        shortAskSystemPromptTemplate = preset.shortAskSystemPrompt
        translateSystemPromptTemplate = preset.translateSystemPrompt
        shortTranslateSystemPromptTemplate = preset.shortTranslateSystemPrompt
        geminiASRPromptTemplate = preset.geminiASRPrompt
        shortGeminiASRPromptTemplate = preset.shortGeminiASRPrompt
    }

    @discardableResult
    func saveCurrentPromptAsNewPreset(named name: String) -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return false }
        let preset = PromptPreset(
            id: "custom.\(UUID().uuidString)",
            name: cleanedName,
            dictateSystemPrompt: dictateSystemPromptTemplate,
            shortDictateSystemPrompt: shortDictateSystemPromptTemplate,
            askSystemPrompt: askSystemPromptTemplate,
            shortAskSystemPrompt: shortAskSystemPromptTemplate,
            translateSystemPrompt: translateSystemPromptTemplate,
            shortTranslateSystemPrompt: shortTranslateSystemPromptTemplate,
            geminiASRPrompt: geminiASRPromptTemplate,
            shortGeminiASRPrompt: shortGeminiASRPromptTemplate,
            isBuiltIn: false,
            updatedAt: Date()
        )
        customPromptPresets.append(preset)
        selectedPromptPresetID = preset.id
        return true
    }

    @discardableResult
    func overwriteSelectedCustomPromptPreset(named name: String?) -> Bool {
        guard let index = customPromptPresets.firstIndex(where: { $0.id == selectedPromptPresetID }) else {
            return false
        }

        let cleanedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        customPromptPresets[index].name = cleanedName.isEmpty ? customPromptPresets[index].name : cleanedName
        customPromptPresets[index].dictateSystemPrompt = dictateSystemPromptTemplate
        customPromptPresets[index].shortDictateSystemPrompt = PromptTemplateCompressor.compress(
            shortDictateSystemPromptTemplate,
            fallback: dictateSystemPromptTemplate
        )
        customPromptPresets[index].askSystemPrompt = askSystemPromptTemplate
        customPromptPresets[index].shortAskSystemPrompt = PromptTemplateCompressor.compress(
            shortAskSystemPromptTemplate,
            fallback: askSystemPromptTemplate
        )
        customPromptPresets[index].translateSystemPrompt = translateSystemPromptTemplate
        customPromptPresets[index].shortTranslateSystemPrompt = PromptTemplateCompressor.compress(
            shortTranslateSystemPromptTemplate,
            fallback: translateSystemPromptTemplate
        )
        customPromptPresets[index].geminiASRPrompt = geminiASRPromptTemplate
        customPromptPresets[index].shortGeminiASRPrompt = PromptTemplateCompressor.compress(
            shortGeminiASRPromptTemplate,
            fallback: geminiASRPromptTemplate
        )
        customPromptPresets[index].isBuiltIn = false
        customPromptPresets[index].updatedAt = Date()
        return true
    }

    @discardableResult
    func deleteSelectedCustomPromptPreset() -> Bool {
        guard let index = customPromptPresets.firstIndex(where: { $0.id == selectedPromptPresetID }) else {
            return false
        }
        customPromptPresets.remove(at: index)
        applyPromptPreset(id: Self.defaultPromptPreset.id)
        return true
    }

    func resolvedDictateSystemPrompt() -> String {
        let useShort = promptLengthMode == .short
        return normalizedPrompt(
            useShort ? shortDictateSystemPromptTemplate : dictateSystemPromptTemplate,
            fallback: useShort ? Self.defaultPromptPreset.shortDictateSystemPrompt : Self.defaultPromptPreset.dictateSystemPrompt
        )
    }

    func resolvedDictateSystemPrompt(lockedDictationPrompt: String?) -> String {
        let locked = (lockedDictationPrompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !locked.isEmpty {
            return locked
        }
        return resolvedDictateSystemPrompt()
    }

    func resolvedDictationPrompt(for preset: PromptPreset) -> String {
        if promptLengthMode == .short {
            return normalizedPrompt(
                preset.shortDictateSystemPrompt,
                fallback: preset.dictateSystemPrompt
            )
        }
        return normalizedPrompt(
            preset.dictateSystemPrompt,
            fallback: Self.defaultPromptPreset.dictateSystemPrompt
        )
    }

    func resolvedAskSystemPrompt() -> String {
        let useShort = promptLengthMode == .short
        return normalizedPrompt(
            useShort ? shortAskSystemPromptTemplate : askSystemPromptTemplate,
            fallback: useShort ? Self.defaultPromptPreset.shortAskSystemPrompt : Self.defaultPromptPreset.askSystemPrompt
        )
    }

    func resolvedTranslateSystemPrompt(targetLanguage: String) -> String {
        let useShort = promptLengthMode == .short
        let template = normalizedPrompt(
            useShort ? shortTranslateSystemPromptTemplate : translateSystemPromptTemplate,
            fallback: useShort ? Self.defaultPromptPreset.shortTranslateSystemPrompt : Self.defaultPromptPreset.translateSystemPrompt
        )
        return template
            .replacingOccurrences(of: "{target_language}", with: targetLanguage)
            .replacingOccurrences(of: "【{target_language}】", with: "【\(targetLanguage)】")
    }

    func resolvedGeminiASRPrompt(language: String) -> String {
        let useShort = promptLengthMode == .short
        let template = normalizedPrompt(
            useShort ? shortGeminiASRPromptTemplate : geminiASRPromptTemplate,
            fallback: useShort ? Self.defaultPromptPreset.shortGeminiASRPrompt : Self.defaultPromptPreset.geminiASRPrompt
        )
        return template.replacingOccurrences(of: "{language}", with: language)
    }

    func applyAutoPromptLength(for llmEngine: LLMEngineOption) {
        guard autoPromptLengthSwitchingEnabled else { return }
        let target: PromptLengthMode = llmEngine.prefersShortPromptTemplate ? .short : .long
        if promptLengthMode != target {
            promptLengthMode = target
        }
    }

    private func normalizedPrompt(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallback
        }
        return trimmed
    }

    private func currentLLMEngineOption() -> LLMEngineOption {
        let rawValue = defaults.string(forKey: "GhostType.llmEngine") ?? LLMEngineOption.localMLX.rawValue
        return LLMEngineOption(rawValue: rawValue) ?? .localMLX
    }

    private static func promptPreset(by id: String, customPresets: [PromptPreset]) -> PromptPreset? {
        builtInPromptPresets.first(where: { $0.id == id }) ?? customPresets.first(where: { $0.id == id })
    }

    private static func loadCustomPromptPresets(from defaults: UserDefaults) -> [PromptPreset] {
        guard let data = defaults.data(forKey: Keys.customPromptPresets) else {
            return []
        }
        do {
            return try JSONDecoder().decode([PromptPreset].self, from: data)
        } catch {
            AppLogger.shared.log("Failed to decode custom prompt presets: \(error.localizedDescription)", type: .warning)
            return []
        }
    }

    private static func persistCustomPromptPresets(_ presets: [PromptPreset], to defaults: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(presets)
            defaults.set(data, forKey: Keys.customPromptPresets)
        } catch {
            AppLogger.shared.log("Failed to encode custom prompt presets for persistence: \(error.localizedDescription)", type: .error)
        }
    }

    private func persistCustomPromptPresets() {
        do {
            let data = try JSONEncoder().encode(customPromptPresets)
            defaults.set(data, forKey: Keys.customPromptPresets)
        } catch {
            AppLogger.shared.log("Failed to encode custom prompt presets: \(error.localizedDescription)", type: .error)
        }
    }

    var userDefaultsForMigration: UserDefaults {
        defaults
    }
}

extension PromptTemplateStore {
    nonisolated static let promptBuilderPresetID = PromptLibraryBuiltins.promptBuilderPresetID
    nonisolated static let imNaturalChatPresetID = PromptLibraryBuiltins.imNaturalChatPresetID
    nonisolated static let workspaceNotesPresetID = PromptLibraryBuiltins.workspaceNotesPresetID
    nonisolated static let emailProfessionalPresetID = PromptLibraryBuiltins.emailProfessionalPresetID
    nonisolated static let ticketUpdatePresetID = PromptLibraryBuiltins.ticketUpdatePresetID
    nonisolated static let workChatBriefPresetID = PromptLibraryBuiltins.workChatBriefPresetID

    nonisolated static let defaultPromptPreset = PromptLibraryBuiltins.defaultPromptPreset
    nonisolated static let builtInPromptPresets = PromptLibraryBuiltins.builtInPromptPresets

    nonisolated static func migratedLegacyPresetID(_ rawID: String?) -> String? {
        PromptPresetMigration.migratedLegacyPresetID(rawID)
    }
}

private extension LLMEngineOption {
    var prefersShortPromptTemplate: Bool {
        switch self {
        case .localMLX, .ollama, .lmStudio:
            return true
        default:
            return false
        }
    }
}

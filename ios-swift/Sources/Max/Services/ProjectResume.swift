import Foundation

enum ProjectMemoryKind: String, CaseIterable {
    case idea = "Idea"
    case decision = "Decision"
    case openItem = "Open item"
    case lesson = "Lesson"
    case nextStep = "Next step"

    func matches(_ fact: UserMemory) -> Bool {
        let name = MemoryIdentity.normalize(fact.key)
        let prefix = MemoryIdentity.normalize(rawValue)
        return name == prefix || name.hasPrefix(prefix + " ")
    }
}

struct ProjectResume {
    static let clarification = "Which project should I resume?"
    let project: String
    let decision: UserMemory?
    let openItem: UserMemory?
    let lesson: UserMemory?
    let idea: UserMemory?
    let nextStep: UserMemory?
    let latestDetail: UserMemory?

    init(project: String, facts: [UserMemory]) {
        self.project = project
        let ordered = facts.filter {
            guard let scope = $0.project else { return false }
            return MemoryIdentity.normalize(scope) == MemoryIdentity.normalize(project)
        }.sorted { $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt }
        decision = ordered.first(where: ProjectMemoryKind.decision.matches)
        openItem = ordered.first(where: ProjectMemoryKind.openItem.matches)
        lesson = ordered.first(where: ProjectMemoryKind.lesson.matches)
        idea = ordered.first(where: ProjectMemoryKind.idea.matches)
        nextStep = ordered.first(where: ProjectMemoryKind.nextStep.matches)
        latestDetail = ordered.first { fact in !ProjectMemoryKind.allCases.contains { $0.matches(fact) } }
    }

    struct Entry: Identifiable {
        let label: String
        let fact: UserMemory
        var id: String { fact.id }
    }

    var entries: [Entry] {
        let sections: [(String, UserMemory?)] = [
            ("Last saved decision", decision), ("Open item", openItem), ("Lesson", lesson),
            ("Idea", idea), ("Saved next step", nextStep), ("Latest other detail", latestDetail)
        ]
        return sections.compactMap { section in
            section.1.map { Entry(label: section.0, fact: $0) }
        }
    }

    var suggestion: String? {
        if nextStep != nil { return nil }
        if let openItem { return "Review the open item “\(openItem.key)” and choose the smallest action that would unblock it." }
        if let idea { return "Pick one small way to try “\(idea.key)” and save what you learn." }
        if let first = entries.first { return "Review “\(first.fact.key)” and save one next action for this project." }
        return nil
    }

    var answer: String {
        var lines = ["From Memory · \(project)"]
        if decision == nil { lines.append("No decision saved yet.") }
        if openItem == nil { lines.append("No open item saved yet.") }
        lines += entries.map { "\($0.label): \($0.fact.value)" }
        if let suggestion { lines.append("Suggested next step: \(suggestion)") }
        return lines.joined(separator: "\n\n")
    }

    static func recognizes(_ text: String) -> Bool {
        let normalized = MemoryIdentity.normalize(text)
        let phrases = ["resume project", "resume my project", "resume this project", "project resume",
                       "where did i stop", "where did i leave off", "where did we leave off",
                       "what should i do next", "what should i try next", "what s next", "next step"]
        return phrases.contains { phrase in
            normalized == phrase || normalized.hasPrefix(phrase + " ")
        }
    }
}

extension StorageService {
    var resumeProjects: [String] {
        guard usesSavedMemory else { return [] }
        var seen: Set<String> = []
        return recallFacts().compactMap(\.project).sorted().filter { seen.insert(MemoryIdentity.normalize($0)).inserted }
    }

    func projectResume(for project: String) -> ProjectResume? {
        guard usesSavedMemory, resumeProjects.contains(where: { MemoryIdentity.normalize($0) == MemoryIdentity.normalize(project) }) else { return nil }
        return ProjectResume(project: project, facts: recallFacts())
    }

    func projectResumeAnswer(messages: [Message]) -> (String, [String])? {
        guard let last = messages.last, last.role == "user" else { return nil }
        let projects = resumeProjects
        let normalized = MemoryIdentity.normalize(last.content)
        let preceding = messages.dropLast().last
        let followsClarification = preceding?.role == "assistant"
            && preceding?.content.hasPrefix(ProjectResume.clarification) == true
        let named = projects.filter {
            followsClarification ? MemoryIdentity.normalize($0) == normalized : MemoryIdentity.mentions($0, in: last.content)
        }
        let unrelatedAdvice = ["what should i do next", "what should i try next", "what s next", "next step"]
            .contains { normalized.hasPrefix($0 + " ") }
        if unrelatedAdvice && named.isEmpty && !MemoryIdentity.mentions("project", in: last.content) { return nil }
        guard ProjectResume.recognizes(last.content) || (followsClarification && !named.isEmpty) else { return nil }
        guard usesSavedMemory else { return ("Saved Memory is paused. Turn it on to resume a project.", []) }
        guard !projects.isEmpty else { return ("No projects are saved in Memory yet. Save an idea, decision, or next step with a project name first.", []) }
        let generic = ["this project", "my project", "the project"].contains { MemoryIdentity.mentions($0, in: last.content) }
        let unnamedRequest = !MemoryIdentity.mentions("project", in: last.content)
            && ["where did i stop", "where did i leave off", "where did we leave off", "what should i do next", "what should i try next", "what s next", "next step"]
                .contains { normalized == $0 || normalized == $0 + " yesterday" }
        let selected = named.count == 1 ? named.first : (named.isEmpty && projects.count == 1 && (generic || unnamedRequest) ? projects.first : nil)
        guard let selected, let snapshot = projectResume(for: selected) else {
            return (ProjectResume.clarification + " " + projects.joined(separator: ", "), [])
        }
        return (snapshot.answer, snapshot.entries.map { $0.fact.id })
    }
}

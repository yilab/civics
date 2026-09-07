import Foundation

final class QuestionRepository {
    private let jsonSource: () -> Data

    init(jsonSource: @escaping () -> Data) {
        self.jsonSource = jsonSource
    }

    /// Parsed once on first access, then cached.
    private(set) lazy var questions: [Question] = {
        guard let file = try? JSONDecoder().decode(QuestionsFile.self, from: jsonSource()) else {
            fatalError("questions.json is missing or malformed")
        }
        return file.questions
    }()

    func deck(category: String, shuffle: Bool) -> [Question] {
        let filtered = category == Categories.all ? questions : questions.filter { $0.category == category }
        return shuffle ? filtered.shuffled() : filtered
    }

    func byNumber(_ n: Int) -> Question? {
        questions.first { $0.n == n }
    }

    static func fromBundle() -> QuestionRepository {
        QuestionRepository {
            guard let url = Bundle.main.url(forResource: "questions", withExtension: "json") else {
                fatalError("questions.json is missing from the bundle")
            }
            return try! Data(contentsOf: url)
        }
    }
}

/// `version` and `count` are metadata the parser ignores.
private struct QuestionsFile: Decodable {
    let questions: [Question]
}

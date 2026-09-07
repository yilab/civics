import Foundation

struct Question: Hashable, Decodable {
    let n: Int
    let category: String
    let question: String
    let answer: String
    /// TTS-friendly rendering of `answer`.
    let spoken: String
    /// True when the answer changes over time or depends on the user's state.
    let dynamic: Bool
    let note: String?
    /// Simplified-Chinese translations; English is used as fallback when absent.
    let questionZh: String?
    let answerZh: String?
    let spokenZh: String?
    let noteZh: String?

    private enum CodingKeys: String, CodingKey {
        case n, category, question, answer, spoken, dynamic, note
        case questionZh, answerZh, spokenZh, noteZh
    }

    init(n: Int, category: String, question: String, answer: String, spoken: String, dynamic: Bool, note: String?,
         questionZh: String? = nil, answerZh: String? = nil, spokenZh: String? = nil, noteZh: String? = nil) {
        self.n = n
        self.category = category
        self.question = question
        self.answer = answer
        self.spoken = spoken
        self.dynamic = dynamic
        self.note = note
        self.questionZh = questionZh
        self.answerZh = answerZh
        self.spokenZh = spokenZh
        self.noteZh = noteZh
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = try c.decode(Int.self, forKey: .n)
        category = try c.decode(String.self, forKey: .category)
        question = try c.decode(String.self, forKey: .question)
        answer = try c.decode(String.self, forKey: .answer)
        spoken = try c.decode(String.self, forKey: .spoken)
        // Absent key decodes as false, like Kotlin's optBoolean("dynamic", false).
        dynamic = try c.decodeIfPresent(Bool.self, forKey: .dynamic) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note)
        questionZh = try c.decodeIfPresent(String.self, forKey: .questionZh)
        answerZh = try c.decodeIfPresent(String.self, forKey: .answerZh)
        spokenZh = try c.decodeIfPresent(String.self, forKey: .spokenZh)
        noteZh = try c.decodeIfPresent(String.self, forKey: .noteZh)
    }
}

enum Categories {
    static let all = "All"
    static let values = [all, "American Government", "American History", "Symbols & Holidays"]
}

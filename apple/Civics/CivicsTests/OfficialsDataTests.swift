import Foundation
import Testing
@testable import Civics

/// Drives the generated officials.json through the same edge cases as the web
/// personalizer smoke test (web/src/officials.js), which it mirrors.
struct OfficialsDataTests {

    private let repo = QuestionRepository.fromBundle()
    private let officials = OfficialsRepository.fromBundle().data

    private static let today = "2026-09-26"

    private func byN(_ list: [Question], _ n: Int) -> Question { list.first { $0.n == n }! }

    @Test func parses56PlacesInPickerOrder() {
        #expect(officials.places.count == 56)
        #expect(officials.places.first?.code == "AL")
        #expect(officials.places[50].code == "DC")
        #expect(officials.places.filter { $0.kind == "territory" }.count == 5)
    }

    @Test func unsetPlaceKeepsBankTextAndPromptsViaSpokenText() {
        let p = officials.personalize(repo.questions, placeCode: nil, district: nil, today: Self.today)
        let q23 = byN(p, 23)
        #expect(q23.answer == "Depends on your state.")
        #expect(q23.spoken.contains("Choose your state in Settings"))
        #expect(q23.translations["zh-Hans"]?.spoken.contains("设置") == true)
        // Untouched questions pass through unchanged.
        #expect(byN(p, 1) == byN(repo.questions, 1))
    }

    @Test func stateFillsSenatorsGovernorAndCapitalInEveryLanguage() {
        let p = officials.personalize(repo.questions, placeCode: "CA", district: nil, today: Self.today)
        let q23 = byN(p, 23)
        #expect(q23.answer.hasPrefix("Either one: "))
        #expect(q23.answer.contains("Alex Padilla"))
        #expect(q23.spoken == q23.answer)
        #expect(byN(p, 61).answer == "Gavin Newsom.")
        #expect(byN(p, 62).answer == "Sacramento.")
        #expect(byN(p, 62).note == nil)
        // Names stay English in the translations; the sentence is localized.
        let zh = q23.translations["zh-Hans"]
        #expect(zh?.answer.hasPrefix("两位中的任意一位") == true)
        #expect(zh?.answer.contains("Alex Padilla") == true)
        #expect(q23.note?.contains("California") == true)
    }

    @Test func multiSeatStateWithoutDistrictPromptsForQ29Only() {
        let p = officials.personalize(repo.questions, placeCode: "CA", district: nil, today: Self.today)
        let q29 = byN(p, 29)
        #expect(q29.answer == "Depends on where you live.")
        #expect(q29.spoken.contains("congressional district"))
        #expect(officials.unresolvedStateQuestions(placeCode: "CA", district: nil) == [29])
        #expect(officials.unresolvedStateQuestions(placeCode: "CA", district: 5).isEmpty)
        #expect(officials.unresolvedStateQuestions(placeCode: nil, district: nil) == OfficialsData.stateQuestions)
        #expect(officials.unresolvedStateQuestions(placeCode: "WY", district: nil).isEmpty)
    }

    @Test func districtResolvesTheRepresentative() {
        let p = officials.personalize(repo.questions, placeCode: "CA", district: 12, today: Self.today)
        #expect(byN(p, 29).answer == "Lateefah Simon.")
        #expect(byN(p, 29).note?.contains("Verify") == true)
    }

    @Test func vacantSeatSaysSoInsteadOfGuessingAName() {
        let p = officials.personalize(repo.questions, placeCode: "FL", district: 20, today: Self.today)
        #expect(byN(p, 29).answer.contains("vacant"))
        #expect(byN(p, 29).answer.contains("house.gov"))
    }

    @Test func districtOfColumbiaGetsItsOwnWording() {
        let p = officials.personalize(repo.questions, placeCode: "DC", district: nil, today: Self.today)
        #expect(byN(p, 23).answer == "There are no U.S. senators for District of Columbia.")
        #expect(byN(p, 29).answer == "Eleanor Holmes Norton.")
        #expect(byN(p, 61).answer == "D.C. does not have a governor.")
        #expect(byN(p, 62).answer == "D.C. is not a state and does not have a capital.")
    }

    @Test func territoryNamesItsDelegateGovernorAndCapital() {
        let p = officials.personalize(repo.questions, placeCode: "PR", district: nil, today: Self.today)
        #expect(byN(p, 29).answer == "Pablo José Hernández.")
        #expect(byN(p, 61).answer == "Jenniffer González-Colón.")
        #expect(byN(p, 62).answer == "San Juan.")
        #expect(byN(p, 23).translations["es"]?.answer.contains("Puerto Rico") == true)
    }

    @Test func expiredTermKeepsTheNameFlaggedAsPossiblyOutOfDate() {
        // Alaska's governor has a staleness marker in December 2026; by January 2027
        // no successor is in the data, so the answer stays but carries the warning.
        let p = officials.personalize(repo.questions, placeCode: "AK", district: nil, today: "2027-01-05")
        #expect(byN(p, 61).answer.hasPrefix("Mike Dunleavy."))
        #expect(byN(p, 61).answer.contains("out of date"))
    }

    @Test func futureEntriesTakeOverOnTheirStartDate() {
        let before = officials.personalize(repo.questions, placeCode: "OH", district: nil, today: "2025-01-20")
        let after = officials.personalize(repo.questions, placeCode: "OH", district: nil, today: "2025-01-21")
        #expect(byN(before, 23).answer.contains("Jon Husted") == false)
        #expect(byN(after, 23).answer.contains("Jon Husted"))
    }

    @Test func districtOptionsCarryCurrentMemberNames() {
        let options = officials.districtOptions(placeCode: "CA", today: Self.today)
        #expect(options.count == 52)
        #expect(options.first { $0.district == 12 }?.name == "Lateefah Simon")
        #expect(officials.districtOptions(placeCode: "WY", today: Self.today).isEmpty)
    }
}

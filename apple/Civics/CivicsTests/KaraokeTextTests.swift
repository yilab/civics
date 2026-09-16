import Foundation
import Testing
@testable import Civics

struct KaraokeTextTests {

    // Offsets into "the Senate and the Senate confirmed": copies at [0, 10)
    // and [15, 25); "and" spans 11..<14.
    private let spoken = "the Senate and the Senate confirmed"
    private let display = "the Senate"

    @Test func aWordInTheFirstCopyLightsTheFirstOccurrence() {
        #expect(KaraokeText.occurrence(of: display, in: spoken, near: 4..<10) == NSRange(location: 0, length: 10))
    }

    @Test func aWordInTheSecondCopyLightsTheSecondOccurrence() {
        #expect(KaraokeText.occurrence(of: display, in: spoken, near: 19..<25) == NSRange(location: 15, length: 10))
    }

    @Test func aWordBetweenCopiesFallsBackToTheFirstOccurrence() {
        #expect(KaraokeText.occurrence(of: display, in: spoken, near: 11..<14) == NSRange(location: 0, length: 10))
    }

    @Test func aPrefixWordStillResolvesToTheOnlyOccurrence() {
        #expect(KaraokeText.occurrence(of: "hi there", in: "Say: hi there", near: 0..<3) == NSRange(location: 5, length: 8))
    }

    @Test func absentDisplayTextResolvesToNil() {
        #expect(KaraokeText.occurrence(of: "the House", in: spoken, near: 0..<3) == nil)
    }

    @Test func emptyDisplayTextResolvesToNil() {
        #expect(KaraokeText.occurrence(of: "", in: spoken, near: 0..<3) == nil)
    }
}

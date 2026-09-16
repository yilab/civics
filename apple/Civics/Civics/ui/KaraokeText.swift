import Foundation
import SwiftUI

/// Karaoke-style rendering for the line currently being spoken: the word the
/// speech engine is on gets a background highlight, advancing word by word.
enum KaraokeText {

    /// Accent wash behind the spoken word, legible in light and dark mode.
    private static let highlightColor = Color.accentColor.opacity(0.3)

    /// `display` with the spoken word lit up, or the plain text when this line
    /// is not the highlight target or no word range has been delivered yet.
    static func text(
        display: String,
        highlight: SpokenHighlight?,
        block: SpokenHighlight.Block,
        isTranslation: Bool,
        speaking: Bool
    ) -> Text {
        guard speaking, let highlight, highlight.block == block,
              highlight.isTranslation == isTranslation, let range = highlight.range else {
            return Text(display)
        }
        let spoken = highlight.text
        // The displayed line usually sits inside the spoken text (an announce
        // prefix may precede it): light the matching slice of the display.
        let base = (spoken as NSString).range(of: display)
        if base.location != NSNotFound {
            guard range.upperBound > base.location else {
                // The spoken word is inside the prefix: nothing to light yet.
                return Text(display)
            }
            let lower = max(range.lowerBound - base.location, 0)
            let upper = min(range.upperBound - base.location, display.utf16.count)
            return Text(highlighted(display, utf16: lower..<upper))
        }
        // Not a substring — the English answer speaks a longer TTS-friendly
        // text: show the spoken text itself while it is being read.
        return Text(highlighted(spoken, utf16: range))
    }

    /// `string` with the accent wash over a UTF-16 range, clamped to the string.
    private static func highlighted(_ string: String, utf16: Range<Int>) -> AttributedString {
        var attr = AttributedString(string)
        guard let word = stringRange(utf16, in: string) else { return attr }
        let start = attr.index(attr.startIndex, offsetByCharacters: string.distance(from: string.startIndex, to: word.lowerBound))
        let end = attr.index(attr.startIndex, offsetByCharacters: string.distance(from: string.startIndex, to: word.upperBound))
        attr[start..<end].backgroundColor = highlightColor
        return attr
    }

    /// Converts UTF-16 offsets into string indices, clamped to the string.
    private static func stringRange(_ utf16: Range<Int>, in string: String) -> Range<String.Index>? {
        let count = string.utf16.count
        let lower = min(max(utf16.lowerBound, 0), count)
        let upper = min(max(utf16.upperBound, 0), count)
        guard lower < upper else { return nil }
        return String.Index(utf16Offset: lower, in: string)..<String.Index(utf16Offset: upper, in: string)
    }
}

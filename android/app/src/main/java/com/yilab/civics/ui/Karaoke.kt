package com.yilab.civics.ui

/**
 * Offset of the occurrence of [display] inside [spoken] that the spoken word
 * range [start]..[end] overlaps most, so a display text repeated in the spoken
 * text lights the copy actually being read. Falls back to the first occurrence
 * when none overlap; -1 when [display] never occurs.
 */
internal fun bestOccurrence(spoken: String, display: String, start: Int, end: Int): Int {
    if (display.isEmpty()) return -1
    var best = -1
    var bestOverlap = -1
    var from = 0
    while (from <= spoken.length) {
        val at = spoken.indexOf(display, from)
        if (at < 0) break
        val overlap = maxOf(0, minOf(at + display.length, end) - maxOf(at, start))
        if (overlap > bestOverlap) {
            best = at
            bestOverlap = overlap
        }
        from = at + 1
    }
    return best
}

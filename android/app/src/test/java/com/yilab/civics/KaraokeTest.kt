package com.yilab.civics

import com.yilab.civics.ui.bestOccurrence
import org.junit.Assert.assertEquals
import org.junit.Test

class KaraokeTest {

    // Offsets into "the Senate and the Senate confirmed": copies at [0, 10)
    // and [15, 25); "and" spans 11..<14.
    private val spoken = "the Senate and the Senate confirmed"
    private val display = "the Senate"

    @Test
    fun aWordInTheFirstCopyLightsTheFirstOccurrence() {
        assertEquals(0, bestOccurrence(spoken, display, 4, 10))
    }

    @Test
    fun aWordInTheSecondCopyLightsTheSecondOccurrence() {
        assertEquals(15, bestOccurrence(spoken, display, 19, 25))
    }

    @Test
    fun aWordBetweenCopiesFallsBackToTheFirstOccurrence() {
        assertEquals(0, bestOccurrence(spoken, display, 11, 14))
    }

    @Test
    fun aPrefixWordStillResolvesToTheOnlyOccurrence() {
        assertEquals(5, bestOccurrence("Say: hi there", "hi there", 0, 3))
    }

    @Test
    fun absentDisplayTextResolvesToMinusOne() {
        assertEquals(-1, bestOccurrence(spoken, "the House", 0, 3))
    }

    @Test
    fun emptyDisplayTextResolvesToMinusOne() {
        assertEquals(-1, bestOccurrence(spoken, "", 0, 3))
    }
}

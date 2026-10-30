package com.lint.share

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Runs every case in shared/tests/link-cases.json, the test set shared with iOS, so both platforms
 * are checked against the same real shared links. All failures are reported together.
 */
class SharedLinkCasesTest {

    private val cases: JSONObject by lazy {
        val path = System.getProperty("lint.sharedLinkCases")
            ?: error("lint.sharedLinkCases isn't set; run the tests through Gradle")
        JSONObject(File(path).readText())
    }

    @Test
    fun `cleans every shared case`() {
        val clean = cases.getJSONArray("clean")
        assertTrue("no clean cases found", clean.length() > 0)

        val failures = (0 until clean.length()).map { clean.getJSONObject(it) }.mapNotNull { case ->
            val actual = UrlCleaner.cleanFirstUrl(case.getString("input"))
            val expected = case.getString("expected")
            if (actual == expected) null
            else "${case.getString("source")}:\n  input:    ${case.getString("input")}\n  expected: $expected\n  actual:   $actual"
        }
        assertEquals("Failing shared cases:\n" + failures.joinToString("\n"), 0, failures.size)
    }

    @Test
    fun `matches every shared short link case`() {
        val shortLinks = cases.getJSONArray("shortLinks")
        assertTrue("no short link cases found", shortLinks.length() > 0)

        val failures = (0 until shortLinks.length()).map { shortLinks.getJSONObject(it) }.mapNotNull { case ->
            val url = case.getString("url")
            val expected = case.getBoolean("known")
            if (ShortLinkResolver.isKnownShortLink(url) == expected) null
            else "${case.getString("source")}: $url should ${if (expected) "" else "not "}be a known short link"
        }
        assertEquals("Failing shared short link cases:\n" + failures.joinToString("\n"), 0, failures.size)
    }
}

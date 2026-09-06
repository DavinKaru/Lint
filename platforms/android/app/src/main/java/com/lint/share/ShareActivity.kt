package com.lint.share

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log

private const val TAG = "Lint"

/**
 * Trampoline activity: receives a share, cleans the URL inside it, and immediately
 * re-shares the cleaned text via a new chooser. Has no UI of its own.
 */
class ShareActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sharedText = intent?.getStringExtra(Intent.EXTRA_TEXT)
        if (sharedText.isNullOrEmpty()) {
            Log.d(TAG, "no EXTRA_TEXT in share intent, finishing")
            finish()
            return
        }

        val urlMatch = UrlCleaner.findFirstUrl(sharedText)

        if (urlMatch != null && ShortLinkResolver.isKnownShortLink(urlMatch.url)) {
            Log.d(TAG, "known short link detected, resolving: ${urlMatch.url}")
            // Short links carry no tracking params directly -- they only appear after the
            // redirect to the full URL, so resolve first. Runs off the main thread since it
            // hits the network; every other link below completes with no thread hop.
            Thread {
                val resolvedUrl = ShortLinkResolver.resolveOverNetwork(urlMatch.url)
                if (resolvedUrl == urlMatch.url) {
                    Log.w(TAG, "resolution failed or timed out, falling back to original short link")
                } else {
                    Log.d(TAG, "resolved to: $resolvedUrl")
                }
                val cleanedUrl = UrlCleaner.cleanUrl(resolvedUrl) ?: resolvedUrl
                val cleanedText = sharedText.replaceRange(urlMatch.range, cleanedUrl)
                Log.d(TAG, "cleaned after resolving: $cleanedText")
                runOnUiThread { reshare(cleanedText) }
            }.start()
        } else {
            val cleanedText = UrlCleaner.cleanFirstUrl(sharedText)
            Log.d(TAG, "cleaned offline: $cleanedText")
            reshare(cleanedText)
        }
    }

    private fun reshare(text: String) {
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }

        startActivity(Intent.createChooser(sendIntent, null))
        finish()
    }
}

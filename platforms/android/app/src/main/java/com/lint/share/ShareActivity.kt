package com.lint.share

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Trampoline activity: receives a share, cleans the URL inside it, and immediately
 * re-shares the cleaned text via a new chooser. Has no UI of its own.
 */
class ShareActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sharedText = intent?.getStringExtra(Intent.EXTRA_TEXT)
        if (sharedText.isNullOrEmpty()) {
            finish()
            return
        }

        val urlMatch = UrlCleaner.findFirstUrl(sharedText)

        if (urlMatch != null && ShortLinkResolver.isAmazonShortLink(urlMatch.url)) {
            // Amazon short links carry no tracking params directly -- they only appear after
            // the redirect to the full product URL, so resolve first. Runs off the main thread
            // since it hits the network; every other link below completes with no thread hop.
            Thread {
                val resolvedUrl = ShortLinkResolver.resolveOverNetwork(urlMatch.url)
                val cleanedUrl = UrlCleaner.cleanUrl(resolvedUrl) ?: resolvedUrl
                val cleanedText = sharedText.replaceRange(urlMatch.range, cleanedUrl)
                runOnUiThread { reshare(cleanedText) }
            }.start()
        } else {
            reshare(UrlCleaner.cleanFirstUrl(sharedText))
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

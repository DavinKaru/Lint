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

        val cleanedText = UrlCleaner.cleanFirstUrl(sharedText)

        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, cleanedText)
        }

        startActivity(Intent.createChooser(sendIntent, null))
        finish()
    }
}

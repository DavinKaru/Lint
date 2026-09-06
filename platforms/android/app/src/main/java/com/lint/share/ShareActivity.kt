package com.lint.share

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.appcompat.R as AppCompatR
import com.google.android.material.R as MaterialR
import com.google.android.material.color.DynamicColors
import com.google.android.material.color.MaterialColors
import com.google.android.material.loadingindicator.LoadingIndicator

private const val TAG = "Lint"

/**
 * Trampoline activity: receives a share, cleans the URL inside it, and immediately
 * re-shares the cleaned text via a new chooser. Has no UI of its own for the common (offline)
 * case. The only exception is a brief loading view shown while a short link is being
 * resolved, since that involves a short network wait.
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
            // Overlays the theme with the user's system/wallpaper palette (Android 12+); a
            // no-op on older versions, which just keep Material3's static baseline colors.
            DynamicColors.applyToActivityIfAvailable(this)
            setContentView(R.layout.activity_resolving)
            val spinner = findViewById<LoadingIndicator>(R.id.resolving_spinner)
            spinner.setIndicatorColor(
                MaterialColors.getColor(spinner, AppCompatR.attr.colorPrimary),
                MaterialColors.getColor(spinner, MaterialR.attr.colorTertiary),
                MaterialColors.getColor(spinner, MaterialR.attr.colorSecondary),
            )
            // Short links carry no tracking params directly -- they only appear after the
            // redirect to the full URL, so resolve first. Runs off the main thread since it
            // hits the network; every other link below completes with no thread hop and no UI.
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

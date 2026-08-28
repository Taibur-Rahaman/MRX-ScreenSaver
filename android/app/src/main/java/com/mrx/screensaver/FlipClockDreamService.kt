package com.mrx.screensaver

import android.service.dreams.DreamService
import android.view.View
import android.view.WindowManager

/**
 * Android screen saver (Daydream). Enable in:
 * Settings → Display → Screen saver → MRX Flip Clock
 */
class FlipClockDreamService : DreamService() {

  private var clock: FlipClockView? = null

  override fun onDreamingStarted() {
    super.onDreamingStarted()
    isInteractive = true
    isFullscreen = true
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

    val view = FlipClockView(this)
    view.systemUiVisibility = (
      View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
        or View.SYSTEM_UI_FLAG_FULLSCREEN
        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
      )
    clock = view
    setContentView(view)
    view.start()
    view.setOnClickListener { finish() }
  }

  override fun onDreamingStopped() {
    clock?.stop()
    clock = null
    super.onDreamingStopped()
  }
}

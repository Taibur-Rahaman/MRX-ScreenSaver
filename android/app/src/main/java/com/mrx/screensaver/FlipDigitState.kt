package com.mrx.screensaver

data class FlipDigitState(
    var current: Int = 0,
    var oldDigit: Int = 0,
    var newDigit: Int = 0,
    var progress: Float = 0f,
    var isFlipping: Boolean = false,
    var flipStartMs: Long = 0L,
)

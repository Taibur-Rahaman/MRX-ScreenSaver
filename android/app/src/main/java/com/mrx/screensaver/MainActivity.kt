package com.mrx.screensaver

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import com.mrx.screensaver.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.flipClock.start()
        binding.root.setOnClickListener { finish() }
        binding.hint.setOnClickListener {
            startActivity(Intent(Settings.ACTION_DREAM_SETTINGS))
        }
    }

    override fun onDestroy() {
        binding.flipClock.stop()
        super.onDestroy()
    }
}

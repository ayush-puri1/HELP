package com.help.sos

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat

class MainActivity : Activity() {
    private val requestCode = 41
    private lateinit var contacts: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = getSharedPreferences("help", MODE_PRIVATE)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 48, 36, 36)
        }
        layout.addView(TextView(this).apply {
            text = "HELP Emergency Assistant\n\nAdd trusted emergency contacts. Enter phone numbers separated by commas, including country code."
            textSize = 18f
        })
        contacts = EditText(this).apply {
            hint = "+9198XXXXXXXX, +9199XXXXXXXX"
            setText(prefs.getString("contacts", ""))
            inputType = android.text.InputType.TYPE_CLASS_PHONE or android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE
        }
        layout.addView(contacts)
        layout.addView(Button(this).apply {
            text = "Save contacts"
            setOnClickListener {
                prefs.edit().putString("contacts", contacts.text.toString()).apply()
                Toast.makeText(this@MainActivity, "Contacts saved on this phone", Toast.LENGTH_SHORT).show()
            }
        })
        layout.addView(TextView(this).apply {
            text = "\nMonitoring requires microphone, location, SMS and notification permissions. A persistent notification will show while monitoring."
            textSize = 14f
        })
        layout.addView(Button(this).apply {
            text = "Enable HELP monitoring"
            setOnClickListener { requestPermissionsIfNeeded() }
        })
        layout.addView(Button(this).apply {
            text = "Stop monitoring"
            setOnClickListener { stopService(Intent(this@MainActivity, HelpMonitorService::class.java)) }
        })
        setContentView(layout)
    }

    private fun requestPermissionsIfNeeded() {
        val permissions = mutableListOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.SEND_SMS
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val needed = permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }.toTypedArray()

        if (needed.isNotEmpty()) {
            requestPermissions(needed, requestCode)
        } else {
            startMonitor()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, results)
        if (requestCode == this.requestCode && results.isNotEmpty() && results.all { it == PackageManager.PERMISSION_GRANTED }) {
            startMonitor()
        } else {
            Toast.makeText(this, "Required permissions were not all granted; monitoring was not started.", Toast.LENGTH_LONG).show()
        }
    }

    private fun startMonitor() {
        val intent = Intent(this, HelpMonitorService::class.java)
        ContextCompat.startForegroundService(this, intent)
        Toast.makeText(this, "HELP monitoring requested", Toast.LENGTH_SHORT).show()
    }
}

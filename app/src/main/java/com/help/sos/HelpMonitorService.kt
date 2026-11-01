package com.help.sos

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.media.MediaRecorder
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.telephony.SmsManager
import androidx.core.app.NotificationCompat
import androidx.core.net.toUri
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * MVP service. SpeechRecognizer is a prototype recogniser, not a production wake-word engine.
 * It can stop, use network services, or be throttled by device/OEM power management.
 */
class HelpMonitorService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private val helpTimes = ArrayDeque<Long>()
    private var countdownRunnable: Runnable? = null
    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var emergencyActive = false
    private val channelId = "help_emergency"

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(10, notification("Monitoring is active. Say HELP three times within 20 seconds."))
        startSpeechRecognition()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            cancelEmergency()
        } else if (intent?.action == ACTION_STOP) {
            stopSelf()
        }
        return START_STICKY
    }

    private fun startSpeechRecognition() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            updateNotification("Speech recognition unavailable on this device.")
            return
        }
        recognizer = if ((Build.VERSION.SDK_INT >= 31) && SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        } else {
            SpeechRecognizer.createSpeechRecognizer(this)
        }
        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { updateNotification("Listening for HELP…") }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) { if (!emergencyActive) handler.postDelayed({ listenAgain() }, 800) }
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
                val heardCount = matches.firstOrNull()?.lowercase(Locale.ROOT)
                    ?.split(Regex("[^a-z]+"))?.count { it == "help" } ?: 0
                repeat(heardCount) { registerHelp() }
                if (!emergencyActive) handler.postDelayed({ listenAgain() }, 300)
            }
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        listenAgain()
    }

    private fun listenAgain() {
        if (emergencyActive) return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        try { recognizer?.startListening(intent) } catch (_: Exception) {
            handler.postDelayed({ listenAgain() }, 1000)
        }
    }

    private fun registerHelp() {
        val now = SystemClock.elapsedRealtime()
        helpTimes.addLast(now)
        while (helpTimes.isNotEmpty() && now - helpTimes.first() > 20_000) helpTimes.removeFirst()
        if (helpTimes.size >= 3 && countdownRunnable == null) beginCountdown()
    }

    private fun beginCountdown() {
        updateNotification("SOS detected. 30 seconds to cancel. Tap notification for cancellation.")
        val cancelIntent = PendingIntent.getService(
            this, 22, Intent(this, HelpMonitorService::class.java).setAction(ACTION_CANCEL),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val cancelNotification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("HELP: Emergency countdown")
            .setContentText("Emergency actions begin in 30 seconds. Tap CANCEL if safe.")
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "CANCEL", cancelIntent)
            .build()
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(10, cancelNotification)

        var seconds = 30
        countdownRunnable = object : Runnable {
            override fun run() {
                if (seconds <= 0) {
                    countdownRunnable = null
                    activateEmergency()
                } else {
                    updateNotification("Emergency actions begin in $seconds seconds. Tap notification to cancel.")
                    seconds--
                    handler.postDelayed(this, 1000)
                }
            }
        }.also { handler.post(it) }
    }

    private fun cancelEmergency() {
        countdownRunnable?.let { handler.removeCallbacks(it) }
        countdownRunnable = null
        helpTimes.clear()
        updateNotification("Emergency cancelled. Monitoring remains active.")
    }

    private fun activateEmergency() {
        emergencyActive = true
        sendEmergencySms()
        startAudioRecording()
        startLocationUpdates()
        showCall112Notification()
        updateNotification("SOS active. SMS sent where possible; location and audio capture running.")
    }

    private fun getSmsManager(): SmsManager {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }

    private fun sendEmergencySms() {
        if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) return
        val prefs = getSharedPreferences("help", MODE_PRIVATE)
        val numbers = prefs.getString("contacts", "").orEmpty()
            .split(",", ";", "\n").asSequence().map { it.trim() }.filter { it.isNotBlank() }.toList()
        val loc = lastKnownLocation()
        val mapLink = loc?.let { "https://maps.google.com/?q=${it.latitude},${it.longitude}" } ?: "Location unavailable; updates will follow."
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val message = "HELP EMERGENCY: The user may need urgent assistance. Time: ${Date()}. Battery: $battery%. Location: $mapLink. Please contact them and call 112 if needed."
        val sms = getSmsManager()
        numbers.forEach { number ->
            try { sms.sendTextMessage(number, null, message, null, null) } catch (_: Exception) {}
        }
    }

    private fun startLocationUpdates() {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
        val runnable = object : Runnable {
            override fun run() {
                if (!emergencyActive) return
                val loc = lastKnownLocation()
                if (loc != null) {
                    val url = "https://maps.google.com/?q=${loc.latitude},${loc.longitude}"
                    sendLocationUpdate(url)
                }
                handler.postDelayed(this, 60_000)
            }
        }
        handler.post(runnable)
    }

    private fun sendLocationUpdate(url: String) {
        if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) return
        val numbers = getSharedPreferences("help", MODE_PRIVATE).getString("contacts", "").orEmpty()
            .split(",", ";", "\n").asSequence().map { it.trim() }.filter { it.isNotBlank() }.toList()
        val sms = getSmsManager()
        numbers.forEach { try { sms.sendTextMessage(it, null, "HELP location update: $url", null, null) } catch (_: Exception) {} }
    }

    private fun lastKnownLocation(): Location? {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) return null
        val lm = getSystemService(LocationManager::class.java) ?: return null
        return try {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .mapNotNull { provider -> try { lm.getLastKnownLocation(provider) } catch (_: Exception) { null } }
                .maxByOrNull { it.time }
        } catch (_: Exception) { null }
    }

    private fun startAudioRecording() {
        try {
            val dir = File(getExternalFilesDir(null), "HELP-recordings").apply { mkdirs() }
            val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
            recordingFile = File(dir, "HELP-$stamp.m4a")
            recorder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else @Suppress("DEPRECATION") MediaRecorder()
            recorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setOutputFile(recordingFile!!.absolutePath)
                prepare()
                start()
            }
            handler.postDelayed({ stopAudioRecording() }, 5 * 60_000L)
        } catch (_: Exception) { stopAudioRecording() }
    }

    private fun stopAudioRecording() {
        try { recorder?.stop() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
    }

    private fun showCall112Notification() {
        val dial = Intent(Intent.ACTION_DIAL, "tel:112".toUri()).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pending = PendingIntent.getActivity(this, 112, dial, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("HELP emergency: Call 112")
            .setContentText("Tap to open the phone dialler with 112.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
        getSystemService(NotificationManager::class.java)?.notify(12, n)
    }

    private fun createChannel() {
        val channel = NotificationChannel(channelId, "HELP emergency status", NotificationManager.IMPORTANCE_HIGH)
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    private fun notification(message: String): Notification {
        val cancelIntent = PendingIntent.getService(
            this, 22, Intent(this, HelpMonitorService::class.java).setAction(ACTION_CANCEL),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("HELP is active")
            .setContentText(message)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "CANCEL", cancelIntent)
            .build()
    }

    private fun updateNotification(message: String) {
        getSystemService(NotificationManager::class.java)?.notify(10, notification(message))
    }

    override fun onDestroy() {
        emergencyActive = false
        try { recognizer?.destroy() } catch (_: Exception) {}
        stopAudioRecording()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null

    companion object {
        const val ACTION_CANCEL = "com.help.sos.CANCEL"
        const val ACTION_STOP = "com.help.sos.STOP"
    }
}

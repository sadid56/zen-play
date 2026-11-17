package com.zenplay.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class BackgroundAudioService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaSession: MediaSession? = null
    private val imageExecutor = Executors.newSingleThreadExecutor()

    private var currentTitle: String = "ZenPlay"
    private var currentArtist: String = "Playing in background"
    private var currentIsPlaying: Boolean = true
    private var currentDurationMs: Long = 0L
    private var currentPositionMs: Long = 0L
    private var currentArtworkUrl: String? = null
    private var currentArtwork: Bitmap? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initMediaSession()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PREV -> {
                onMediaAction?.invoke("previous", null)
                return START_STICKY
            }
            ACTION_PLAY_PAUSE -> {
                onMediaAction?.invoke(if (currentIsPlaying) "pause" else "play", null)
                return START_STICKY
            }
            ACTION_NEXT -> {
                onMediaAction?.invoke("next", null)
                return START_STICKY
            }
        }

        if (intent?.hasExtra(EXTRA_TITLE) == true) {
            currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: "ZenPlay"
            currentArtist = intent.getStringExtra(EXTRA_ARTIST) ?: "ZenPlay"
            currentIsPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, true)
            currentDurationMs = intent.getLongExtra(EXTRA_DURATION_MS, 0L)
            currentPositionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0L)
            val artworkUrl = intent.getStringExtra(EXTRA_ARTWORK_URL)
            if (!artworkUrl.isNullOrEmpty() && artworkUrl != currentArtworkUrl) {
                currentArtworkUrl = artworkUrl
                loadArtworkAsync(artworkUrl)
            }
        }

        updateMediaSessionState()
        val notification = buildMediaNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        acquireWakeLock()
        return START_STICKY
    }

    override fun onDestroy() {
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        imageExecutor.shutdownNow()
        releaseWakeLock()
        super.onDestroy()
    }

    private fun initMediaSession() {
        mediaSession = MediaSession(this, "ZenPlayMediaSession").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    onMediaAction?.invoke("play", null)
                }

                override fun onPause() {
                    onMediaAction?.invoke("pause", null)
                }

                override fun onSkipToNext() {
                    onMediaAction?.invoke("next", null)
                }

                override fun onSkipToPrevious() {
                    onMediaAction?.invoke("previous", null)
                }

                override fun onSeekTo(pos: Long) {
                    onMediaAction?.invoke("seekTo", pos)
                }
            })
            isActive = true
        }
    }

    private fun updateMediaSessionState() {
        val session = mediaSession ?: return
        val metadataBuilder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, currentTitle)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, currentArtist)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, currentDurationMs)

        currentArtwork?.let {
            metadataBuilder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it)
        }
        session.setMetadata(metadataBuilder.build())

        val stateCode = if (currentIsPlaying) {
            PlaybackState.STATE_PLAYING
        } else {
            PlaybackState.STATE_PAUSED
        }
        val playbackState = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or
                    PlaybackState.ACTION_PAUSE or
                    PlaybackState.ACTION_PLAY_PAUSE or
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackState.ACTION_SEEK_TO
            )
            .setState(stateCode, currentPositionMs, if (currentIsPlaying) 1.0f else 0.0f)
            .build()
        session.setPlaybackState(playbackState)
    }

    private fun buildMediaNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val prevPending = serviceActionPendingIntent(ACTION_PREV, 1)
        val playPausePending = serviceActionPendingIntent(ACTION_PLAY_PAUSE, 2)
        val nextPending = serviceActionPendingIntent(ACTION_NEXT, 3)

        val playPauseIcon = if (currentIsPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val playPauseLabel = if (currentIsPlaying) "Pause" else "Play"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setContentTitle(currentTitle)
            .setContentText(currentArtist)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(contentIntent)
            .setOngoing(currentIsPlaying)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_previous,
                    "Previous",
                    prevPending
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    playPauseIcon,
                    playPauseLabel,
                    playPausePending
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_next,
                    "Next",
                    nextPending
                ).build()
            )

        currentArtwork?.let { builder.setLargeIcon(it) }

        mediaSession?.let { session ->
            builder.setStyle(
                Notification.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
        }

        return builder.build()
    }

    private fun serviceActionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, BackgroundAudioService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun loadArtworkAsync(url: String) {
        imageExecutor.execute {
            try {
                val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 4000
                    readTimeout = 4000
                }
                val bmp = conn.inputStream.use { BitmapFactory.decodeStream(it) }
                conn.disconnect()
                if (bmp != null) {
                    Handler(Looper.getMainLooper()).post {
                        if (url == currentArtworkUrl && mediaSession != null) {
                            currentArtwork = bmp
                            updateMediaSessionState()
                            val manager = getSystemService(NotificationManager::class.java)
                            manager?.notify(NOTIFICATION_ID, buildMediaNotification())
                        }
                    }
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ZenPlay::AudioWakeLock").apply {
            acquire(60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "zenplay_playback"
        private const val NOTIFICATION_ID = 1001

        const val ACTION_PREV = "com.zenplay.app.ACTION_PREV"
        const val ACTION_PLAY_PAUSE = "com.zenplay.app.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.zenplay.app.ACTION_NEXT"

        const val EXTRA_TITLE = "title"
        const val EXTRA_ARTIST = "artist"
        const val EXTRA_IS_PLAYING = "isPlaying"
        const val EXTRA_DURATION_MS = "durationMs"
        const val EXTRA_POSITION_MS = "positionMs"
        const val EXTRA_ARTWORK_URL = "artworkUrl"

        var onMediaAction: ((action: String, arg: Any?) -> Unit)? = null
    }
}

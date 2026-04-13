package com.max.ai.services

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.speech.tts.TextToSpeech
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.io.IOException
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume

class VoiceService(private val context: Context) {

    private var mediaRecorder: MediaRecorder? = null
    private var audioFile: File? = null
    private var tts: TextToSpeech? = null
    private var isTtsReady = false

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    // ─── TTS ──────────────────────────────────────────────────────────────────

    fun initTts(onReady: () -> Unit = {}) {
        tts = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.US
                tts?.setSpeechRate(1.0f)
                tts?.setPitch(1.0f)
                isTtsReady = true
                onReady()
            } else {
                Log.w(TAG, "TTS init failed with status: $status")
            }
        }
    }

    fun speak(text: String) {
        if (!isTtsReady) {
            Log.w(TAG, "TTS not ready, initializing...")
            initTts { speak(text) }
            return
        }
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "max_tts_${System.currentTimeMillis()}")
    }

    fun stopSpeaking() {
        tts?.stop()
    }

    fun isSpeaking(): Boolean = tts?.isSpeaking ?: false

    fun releaseTts() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        isTtsReady = false
    }

    // ─── Recording ────────────────────────────────────────────────────────────

    @Suppress("DEPRECATION")
    suspend fun startRecording() = withContext(Dispatchers.IO) {
        stopRecording()

        audioFile = File(context.cacheDir, "max_recording_${System.currentTimeMillis()}.m4a")

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            MediaRecorder()
        }.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(16000)
            setAudioEncodingBitRate(128000)
            setOutputFile(audioFile!!.absolutePath)
            prepare()
            start()
        }

        Log.d(TAG, "Recording started: ${audioFile?.absolutePath}")
    }

    fun stopRecording() {
        runCatching {
            mediaRecorder?.apply {
                stop()
                release()
            }
        }.onFailure { Log.e(TAG, "Error stopping recorder", it) }
        mediaRecorder = null
    }

    /**
     * Stop recording and transcribe the audio using Claude claude-haiku-4-5.
     * Audio is base64-encoded and sent to the Messages API with a document/audio block.
     *
     * @param apiKey Anthropic API key
     * @return Transcribed text, or null on failure
     */
    suspend fun stopAndTranscribe(apiKey: String): String? = withContext(Dispatchers.IO) {
        stopRecording()

        val file = audioFile ?: return@withContext null

        if (!file.exists() || file.length() == 0L) {
            Log.w(TAG, "Audio file empty or missing")
            return@withContext null
        }

        runCatching {
            val audioBytes = file.readBytes()
            val base64Audio = Base64.encodeToString(audioBytes, Base64.NO_WRAP)

            val requestBody = buildJsonObject {
                put("model", "claude-haiku-4-5")
                put("max_tokens", 1024)
                put("messages", buildJsonArray {
                    add(buildJsonObject {
                        put("role", "user")
                        put("content", buildJsonArray {
                            add(buildJsonObject {
                                put("type", "document")
                                put("source", buildJsonObject {
                                    put("type", "base64")
                                    put("media_type", "audio/mp4")
                                    put("data", base64Audio)
                                })
                            })
                            add(buildJsonObject {
                                put("type", "text")
                                put("text", "Please transcribe this audio recording exactly as spoken. Return only the transcription text, no additional commentary.")
                            })
                        })
                    })
                })
            }.toString()

            val request = Request.Builder()
                .url("https://api.anthropic.com/v1/messages")
                .post(requestBody.toRequestBody("application/json; charset=utf-8".toMediaType()))
                .header("x-api-key", apiKey)
                .header("anthropic-version", "2023-06-01")
                .header("content-type", "application/json")
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: return@runCatching null

            if (!response.isSuccessful) {
                Log.e(TAG, "Transcription error ${response.code}: $responseBody")
                return@runCatching null
            }

            val jsonElement = Json.parseToJsonElement(responseBody).jsonObject
            jsonElement["content"]
                ?.jsonArray
                ?.firstOrNull()
                ?.jsonObject
                ?.get("text")
                ?.jsonPrimitive
                ?.content
        }.onFailure { Log.e(TAG, "Transcription failed", it) }.getOrNull().also {
            audioFile?.delete()
            audioFile = null
        }
    }

    fun stop() {
        stopRecording()
        stopSpeaking()
    }

    fun release() {
        stop()
        releaseTts()
    }

    companion object {
        private const val TAG = "VoiceService"
    }
}

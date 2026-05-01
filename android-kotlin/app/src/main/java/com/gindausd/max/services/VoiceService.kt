package com.gindausd.max.services

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.Locale
import kotlin.coroutines.resume

class VoiceService private constructor(private val context: Context) {

    private var speechRecognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false

    var isSpeaking: Boolean = false
        private set

    init {
        initTTS()
    }

    private fun initTTS() {
        textToSpeech = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val result = textToSpeech?.setLanguage(Locale.US)
                ttsReady = result != TextToSpeech.LANG_MISSING_DATA &&
                        result != TextToSpeech.LANG_NOT_SUPPORTED
                textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        isSpeaking = true
                    }

                    override fun onDone(utteranceId: String?) {
                        isSpeaking = false
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        isSpeaking = false
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        isSpeaking = false
                    }
                })
            }
        }
    }

    fun startListening(onResult: (String?) -> Unit) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            onResult(null)
            return
        }

        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                onResult(matches?.firstOrNull())
            }

            override fun onPartialResults(partialResults: Bundle?) {}

            override fun onError(error: Int) {
                onResult(null)
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        speechRecognizer?.startListening(intent)
    }

    fun stopListening() {
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    fun speak(text: String, voice: String = "female") {
        if (!ttsReady) return
        if (text.isBlank()) return

        // Select voice based on preference
        val voices = textToSpeech?.voices
        if (voices != null) {
            val preferred = if (voice == "male") {
                voices.firstOrNull { it.locale == Locale.US && it.name.contains("male", ignoreCase = true) && !it.name.contains("female", ignoreCase = true) }
            } else {
                voices.firstOrNull { it.locale == Locale.US && it.name.contains("female", ignoreCase = true) }
            }
            if (preferred != null) {
                textToSpeech?.voice = preferred
            } else {
                textToSpeech?.setLanguage(Locale.US)
            }
        }

        val utteranceId = "max_utterance_${System.currentTimeMillis()}"
        textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        isSpeaking = true
    }

    fun stopSpeaking() {
        textToSpeech?.stop()
        isSpeaking = false
    }

    fun release() {
        stopListening()
        stopSpeaking()
        textToSpeech?.shutdown()
        textToSpeech = null
    }

    companion object {
        @Volatile private var INSTANCE: VoiceService? = null
        fun getInstance(context: Context): VoiceService =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: VoiceService(context.applicationContext).also { INSTANCE = it }
            }
    }
}

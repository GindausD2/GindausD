package com.gindausd.max.viewmodels

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.gindausd.max.Conversation
import com.gindausd.max.ConversationState
import com.gindausd.max.Message
import com.gindausd.max.OrbState
import com.gindausd.max.data.AuthRepository
import com.gindausd.max.data.StorageRepository
import com.gindausd.max.ui.widget.MaxGlanceWidget
import com.gindausd.max.services.ClaudeChunk
import com.gindausd.max.services.ClaudeService
import com.gindausd.max.services.ToolsService
import com.gindausd.max.services.VoiceService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.UUID

class HomeViewModel(application: Application) : AndroidViewModel(application) {

    private val storage = StorageRepository.getInstance(application)
    private val claude = ClaudeService.getInstance()
    private val voice = VoiceService.getInstance(application)
    private val tools = ToolsService.getInstance()
    private val authRepo = AuthRepository.getInstance(application)
    private val appContext = application.applicationContext
    private val connectivityManager =
        appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val _messages = MutableStateFlow<List<Message>>(emptyList())
    val messages: StateFlow<List<Message>> = _messages.asStateFlow()

    private val _conversationState = MutableStateFlow(ConversationState.IDLE)
    val conversationState: StateFlow<ConversationState> = _conversationState.asStateFlow()

    private val _orbState = MutableStateFlow(OrbState.IDLE)
    val orbState: StateFlow<OrbState> = _orbState.asStateFlow()

    private val _streamingText = MutableStateFlow("")
    val streamingText: StateFlow<String> = _streamingText.asStateFlow()

    private val _isTranscribing = MutableStateFlow(false)
    val isTranscribing: StateFlow<Boolean> = _isTranscribing.asStateFlow()

    private val _pendingImage = MutableStateFlow<Bitmap?>(null)
    val pendingImage: StateFlow<Bitmap?> = _pendingImage.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isOffline = MutableStateFlow(false)
    val isOffline: StateFlow<Boolean> = _isOffline.asStateFlow()

    val isDemo: Boolean get() = authRepo.currentUser.value?.isDemo == true
    val demoTrialDaysRemaining: Int get() = authRepo.demoTrialDaysRemaining

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) { _isOffline.value = false }
        override fun onLost(network: Network) { _isOffline.value = !isNetworkAvailable() }
    }

    private fun isNetworkAvailable(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val caps = connectivityManager.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    init {
        loadMessages()
        _isOffline.value = !isNetworkAvailable()
        connectivityManager.registerDefaultNetworkCallback(networkCallback)
    }

    fun loadMessages() {
        viewModelScope.launch {
            val msgs = withContext(Dispatchers.IO) { storage.loadMessages() }
            _messages.value = msgs
        }
    }

    fun handleOrbTap() {
        when (_conversationState.value) {
            ConversationState.IDLE -> startListening()
            ConversationState.LISTENING -> stopListeningAndProcess()
            ConversationState.SPEAKING -> {
                voice.stopSpeaking()
                setState(ConversationState.IDLE)
            }
            ConversationState.THINKING -> {
                // Cannot cancel mid-stream easily; ignore
            }
        }
    }

    private fun startListening() {
        setState(ConversationState.LISTENING)
        _isTranscribing.value = true

        voice.startListening { result ->
            _isTranscribing.value = false
            if (result != null && result.isNotBlank()) {
                viewModelScope.launch {
                    addUserMessage(result)
                    val imageData = _pendingImage.value?.toJpegBytes()
                    _pendingImage.value = null
                    streamResponse(result, imageData)
                }
            } else {
                setState(ConversationState.IDLE)
            }
        }
    }

    private fun stopListeningAndProcess() {
        voice.stopListening()
        _isTranscribing.value = false
        setState(ConversationState.IDLE)
    }

    private suspend fun addUserMessage(text: String) {
        val msg = Message(
            id = UUID.randomUUID().toString(),
            role = "user",
            content = text,
            timestamp = System.currentTimeMillis()
        )
        val updated = _messages.value + msg
        _messages.value = updated
        withContext(Dispatchers.IO) { storage.saveMessages(updated) }
    }

    private fun streamResponse(userText: String, imageData: ByteArray?) {
        viewModelScope.launch {
            setState(ConversationState.THINKING)

            val streamingId = UUID.randomUUID().toString()
            val streamingMsg = Message(
                id = streamingId,
                role = "assistant",
                content = "",
                timestamp = System.currentTimeMillis(),
                isStreaming = true
            )
            _messages.value = _messages.value + streamingMsg

            var fullText = StringBuilder()
            var pendingToolName: String? = null

            val settings = withContext(Dispatchers.IO) { storage.loadSettings() }

            claude.streamMessage(
                messages = _messages.value.filter { !it.isStreaming && it.id != streamingId },
                imageData = imageData
            ) { chunk ->
                when (chunk) {
                    is ClaudeChunk.Text -> {
                        fullText.append(chunk.text)
                        _messages.value = _messages.value.map { msg ->
                            if (msg.id == streamingId) msg.copy(content = fullText.toString())
                            else msg
                        }
                    }
                    is ClaudeChunk.ToolStart -> {
                        pendingToolName = chunk.name
                        val toolMsg = "Using tool: ${chunk.name}..."
                        _messages.value = _messages.value.map { msg ->
                            if (msg.id == streamingId) msg.copy(content = toolMsg)
                            else msg
                        }
                    }
                    is ClaudeChunk.ToolDone -> {
                        val toolName = chunk.name
                        val inputMap = parseToolInput(chunk.inputJson)
                        val result = try {
                            tools.handleToolCall(appContext, toolName, inputMap)
                        } catch (e: Exception) {
                            "Tool error: ${e.message}"
                        }
                        fullText.clear()
                        fullText.append(result)
                        _messages.value = _messages.value.map { msg ->
                            if (msg.id == streamingId) msg.copy(content = result)
                            else msg
                        }
                        pendingToolName = null
                    }
                    is ClaudeChunk.Done -> {
                        val finalText = fullText.toString()
                        val finalMsg = Message(
                            id = streamingId,
                            role = "assistant",
                            content = finalText,
                            timestamp = System.currentTimeMillis(),
                            isStreaming = false
                        )
                        val finalList = _messages.value.map { if (it.id == streamingId) finalMsg else it }
                        _messages.value = finalList
                        viewModelScope.launch(Dispatchers.IO) {
                            storage.saveMessages(finalList)
                            MaxGlanceWidget.push(appContext, finalText)
                        }

                        if (settings.voiceEnabled && finalText.isNotBlank()) {
                            setState(ConversationState.SPEAKING)
                            voice.speak(finalText, settings.preferredVoice)
                            // Poll until done speaking
                            viewModelScope.launch {
                                kotlinx.coroutines.delay(500)
                                while (voice.isSpeaking) {
                                    kotlinx.coroutines.delay(200)
                                }
                                setState(ConversationState.IDLE)
                            }
                        } else {
                            setState(ConversationState.IDLE)
                        }
                    }
                    is ClaudeChunk.Error -> {
                        val errText = "Error: ${chunk.message}"
                        val errMsg = Message(
                            id = streamingId,
                            role = "assistant",
                            content = errText,
                            timestamp = System.currentTimeMillis(),
                            isStreaming = false
                        )
                        _messages.value = _messages.value.map { if (it.id == streamingId) errMsg else it }
                        _errorMessage.value = chunk.message
                        setState(ConversationState.IDLE)
                    }
                }
            }
        }
    }

    fun sendTextMessage(text: String) {
        if (text.isBlank()) return
        viewModelScope.launch {
            addUserMessage(text)
            streamResponse(text, null)
        }
    }

    fun sendPlacesQuery() {
        sendTextMessage("What interesting places or things to do are nearby?")
    }

    fun startMorningBriefing() {
        sendTextMessage(
            "Give me my morning briefing. Please: " +
            "1) check today's weather and forecast, " +
            "2) list any calendar events today, " +
            "3) give me top news headlines, " +
            "4) share one motivational thought. Keep it concise and upbeat."
        )
    }

    fun clearHistory() {
        viewModelScope.launch {
            _messages.value = emptyList()
            withContext(Dispatchers.IO) { storage.saveMessages(emptyList()) }
        }
    }

    fun startNewChat() {
        viewModelScope.launch {
            val currentMsgs = _messages.value
            if (currentMsgs.isNotEmpty()) {
                val firstUserMsg = currentMsgs.firstOrNull { it.role == "user" }?.content ?: "Conversation"
                val title = firstUserMsg.take(50)
                val conversation = Conversation(
                    id = UUID.randomUUID().toString(),
                    title = title,
                    messages = currentMsgs,
                    startedAt = currentMsgs.firstOrNull()?.timestamp ?: System.currentTimeMillis(),
                    updatedAt = System.currentTimeMillis()
                )
                withContext(Dispatchers.IO) {
                    storage.saveConversation(conversation)
                    storage.saveMessages(emptyList())
                }
            }
            _messages.value = emptyList()
        }
    }

    fun setPendingImage(bitmap: Bitmap?) {
        _pendingImage.value = bitmap
    }

    fun sendImageMessage(bitmap: Bitmap) {
        viewModelScope.launch {
            val imageData = bitmap.toJpegBytes()
            addUserMessage("[Image attached]")
            streamResponse("Please describe and analyze this image.", imageData)
        }
    }

    fun dismissError() {
        _errorMessage.value = null
    }

    private fun setState(state: ConversationState) {
        _conversationState.value = state
        _orbState.value = when (state) {
            ConversationState.IDLE -> OrbState.IDLE
            ConversationState.LISTENING -> OrbState.LISTENING
            ConversationState.THINKING -> OrbState.THINKING
            ConversationState.SPEAKING -> OrbState.SPEAKING
        }
    }

    private fun parseToolInput(inputJson: String): Map<String, Any> {
        if (inputJson.isBlank()) return emptyMap()
        return try {
            val obj = JSONObject(inputJson)
            val result = mutableMapOf<String, Any>()
            for (key in obj.keys()) {
                result[key] = obj.get(key)
            }
            result
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private fun Bitmap.toJpegBytes(): ByteArray {
        val stream = ByteArrayOutputStream()
        compress(Bitmap.CompressFormat.JPEG, 85, stream)
        return stream.toByteArray()
    }

    override fun onCleared() {
        super.onCleared()
        voice.stopSpeaking()
        voice.stopListening()
        connectivityManager.unregisterNetworkCallback(networkCallback)
    }
}

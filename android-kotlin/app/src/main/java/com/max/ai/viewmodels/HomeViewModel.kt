package com.max.ai.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.max.ai.AuthUser
import com.max.ai.ClaudeMessage
import com.max.ai.Message
import com.max.ai.OrbState
import com.max.ai.services.AuthRepository
import com.max.ai.services.ClaudeService
import com.max.ai.services.StorageRepository
import com.max.ai.services.StreamChunk
import com.max.ai.services.ToolsService
import com.max.ai.services.VoiceService
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

data class HomeUiState(
    val messages: List<Message> = emptyList(),
    val orbState: OrbState = OrbState.IDLE,
    val isRecording: Boolean = false,
    val isThinking: Boolean = false,
    val isSpeaking: Boolean = false,
    val currentUser: AuthUser? = null,
    val apiKey: String = "",
    val voiceEnabled: Boolean = false,
    val error: String? = null,
    val statusMessage: String? = null,
    val inputText: String = "",
    val pendingImageBytes: ByteArray? = null
)

class HomeViewModel(
    private val authRepository: AuthRepository,
    private val storageRepository: StorageRepository,
    private val claudeService: ClaudeService,
    private val voiceService: VoiceService,
    private val toolsService: ToolsService
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    private var streamingJob: Job? = null
    private var currentStreamingMessageId: String? = null

    init {
        loadInitialState()
    }

    // ─── Initialization ───────────────────────────────────────────────────────

    private fun loadInitialState() {
        val user = authRepository.getUser()
        val settings = storageRepository.getSettings()
        val messages = storageRepository.getMessages()

        _uiState.update {
            it.copy(
                currentUser = user,
                apiKey = settings.apiKey,
                voiceEnabled = settings.voiceEnabled,
                messages = messages
            )
        }

        viewModelScope.launch {
            storageRepository.settingsFlow.collect { settings ->
                _uiState.update { it.copy(apiKey = settings.apiKey, voiceEnabled = settings.voiceEnabled) }
            }
        }
    }

    // ─── Refresh / Clear ──────────────────────────────────────────────────────

    fun refreshHistory() {
        val messages = storageRepository.getMessages()
        _uiState.update { it.copy(messages = messages, error = null) }
    }

    fun clearHistory() {
        storageRepository.clearMessages()
        _uiState.update { it.copy(messages = emptyList()) }
    }

    // ─── Mic interaction ──────────────────────────────────────────────────────

    fun onMicPressed() {
        val state = _uiState.value
        if (state.isRecording) {
            stopRecordingAndProcess()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        if (_uiState.value.apiKey.isBlank()) {
            _uiState.update { it.copy(error = "Please set your API key in Settings") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isRecording = true, orbState = OrbState.LISTENING, error = null, statusMessage = "Listening...") }
            voiceService.startRecording()
        }
    }

    private fun stopRecordingAndProcess() {
        _uiState.update { it.copy(isRecording = false, orbState = OrbState.THINKING, statusMessage = "Transcribing...") }

        viewModelScope.launch {
            val transcription = voiceService.stopAndTranscribe(_uiState.value.apiKey)

            if (transcription.isNullOrBlank()) {
                _uiState.update {
                    it.copy(
                        orbState = OrbState.IDLE,
                        statusMessage = null,
                        error = "Could not transcribe audio. Please try again."
                    )
                }
                return@launch
            }

            sendMessage(transcription) // voice path — no image
        }
    }

    // ─── Text input ───────────────────────────────────────────────────────────

    fun onInputTextChanged(text: String) = _uiState.update { it.copy(inputText = text) }

    fun onImageSelected(bytes: ByteArray) = _uiState.update { it.copy(pendingImageBytes = bytes) }

    fun clearPendingImage() = _uiState.update { it.copy(pendingImageBytes = null) }

    // ─── Send text message ────────────────────────────────────────────────────

    fun sendTextMessage() {
        val state = _uiState.value
        val text = state.inputText.trim()
        val imageBytes = state.pendingImageBytes
        if (text.isBlank() && imageBytes == null) return

        val apiKey = state.apiKey
        if (apiKey.isBlank()) {
            _uiState.update { it.copy(error = "Please set your API key in Settings") }
            return
        }

        val displayText = if (text.isBlank()) "What do you see in this image?" else text
        val userMsg = Message(
            id = UUID.randomUUID().toString(),
            role = "user",
            content = displayText,
            timestamp = System.currentTimeMillis()
        )
        val updatedMessages = state.messages + userMsg
        _uiState.update { it.copy(messages = updatedMessages, inputText = "", pendingImageBytes = null, error = null) }
        storageRepository.saveMessages(updatedMessages)

        streamResponse(apiKey, imageBytes)
    }

    fun sendMessage(text: String) {
        if (text.isBlank()) return
        val apiKey = _uiState.value.apiKey
        if (apiKey.isBlank()) {
            _uiState.update { it.copy(error = "Please set your API key in Settings") }
            return
        }
        val userMsg = Message(
            id = UUID.randomUUID().toString(),
            role = "user",
            content = text.trim(),
            timestamp = System.currentTimeMillis()
        )
        val updatedMessages = _uiState.value.messages + userMsg
        _uiState.update { it.copy(messages = updatedMessages, error = null) }
        storageRepository.saveMessages(updatedMessages)
        streamResponse(apiKey)
    }

    // ─── Claude streaming ─────────────────────────────────────────────────────

    private fun streamResponse(apiKey: String, imageBytes: ByteArray? = null) {
        streamingJob?.cancel()

        val assistantMsgId = UUID.randomUUID().toString()
        currentStreamingMessageId = assistantMsgId

        // Placeholder streaming message
        val streamingMsg = Message(
            id = assistantMsgId,
            role = "assistant",
            content = "",
            timestamp = System.currentTimeMillis(),
            isStreaming = true
        )
        val messagesWithStreaming = _uiState.value.messages + streamingMsg
        _uiState.update {
            it.copy(
                messages = messagesWithStreaming,
                isThinking = true,
                orbState = OrbState.THINKING,
                statusMessage = "Thinking..."
            )
        }

        // Build Claude conversation history
        val claudeMessages = buildClaudeHistory()

        streamingJob = viewModelScope.launch {
            var accumulatedText = ""

            claudeService.streamResponse(
                apiKey = apiKey,
                messages = claudeMessages,
                imageBytes = imageBytes,
                onToolCall = { name, toolUseId, inputMap ->
                    _uiState.update { it.copy(statusMessage = "Using tool: $name...") }
                    toolsService.execute(name, inputMap)
                }
            ).collect { chunk ->
                when (chunk) {
                    is StreamChunk.Text -> {
                        accumulatedText += chunk.delta
                        updateStreamingMessage(assistantMsgId, accumulatedText)
                        if (!_uiState.value.isSpeaking && _uiState.value.orbState != OrbState.SPEAKING) {
                            _uiState.update { it.copy(orbState = OrbState.SPEAKING, statusMessage = "Responding...") }
                        }
                    }
                    is StreamChunk.ToolStart -> {
                        _uiState.update { it.copy(statusMessage = "Using: ${chunk.name}") }
                    }
                    is StreamChunk.ToolDone -> {
                        _uiState.update { it.copy(orbState = OrbState.THINKING, statusMessage = "Processing...") }
                    }
                    is StreamChunk.Done -> {
                        finalizeStreamingMessage(assistantMsgId, accumulatedText)
                        if (_uiState.value.voiceEnabled && accumulatedText.isNotBlank()) {
                            _uiState.update { it.copy(isSpeaking = true, orbState = OrbState.SPEAKING) }
                            voiceService.speak(accumulatedText)
                        } else {
                            _uiState.update { it.copy(isThinking = false, isSpeaking = false, orbState = OrbState.IDLE, statusMessage = null) }
                        }
                    }
                    is StreamChunk.Error -> {
                        finalizeStreamingMessage(assistantMsgId, accumulatedText.ifEmpty { "Sorry, I encountered an error. Please try again." })
                        _uiState.update {
                            it.copy(
                                isThinking = false,
                                orbState = OrbState.IDLE,
                                statusMessage = null,
                                error = chunk.message
                            )
                        }
                    }
                    else -> { /* ToolInput ignored for display */ }
                }
            }
        }
    }

    private fun updateStreamingMessage(id: String, text: String) {
        val current = _uiState.value.messages.toMutableList()
        val idx = current.indexOfFirst { it.id == id }
        if (idx >= 0) {
            current[idx] = current[idx].copy(content = text)
            _uiState.update { it.copy(messages = current) }
        }
    }

    private fun finalizeStreamingMessage(id: String, text: String) {
        val current = _uiState.value.messages.toMutableList()
        val idx = current.indexOfFirst { it.id == id }
        if (idx >= 0) {
            current[idx] = current[idx].copy(content = text, isStreaming = false)
            _uiState.update { it.copy(messages = current, isThinking = false) }
            storageRepository.saveMessages(current)
        }
    }

    private fun buildClaudeHistory(): List<ClaudeMessage> {
        return _uiState.value.messages
            .filter { !it.isStreaming }
            .takeLast(40) // limit context window
            .map { msg -> ClaudeMessage(role = msg.role, content = msg.content) }
    }

    // ─── Speaking done callback ───────────────────────────────────────────────

    fun onSpeakingFinished() {
        _uiState.update { it.copy(isSpeaking = false, orbState = OrbState.IDLE, statusMessage = null) }
    }

    // ─── Cleanup ──────────────────────────────────────────────────────────────

    override fun onCleared() {
        super.onCleared()
        streamingJob?.cancel()
        voiceService.stop()
    }

    // ─── Factory ──────────────────────────────────────────────────────────────

    class Factory(
        private val authRepository: AuthRepository,
        private val storageRepository: StorageRepository,
        private val claudeService: ClaudeService,
        private val voiceService: VoiceService,
        private val toolsService: ToolsService
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(HomeViewModel::class.java)) {
                return HomeViewModel(
                    authRepository, storageRepository, claudeService, voiceService, toolsService
                ) as T
            }
            throw IllegalArgumentException("Unknown ViewModel: ${modelClass.name}")
        }
    }
}

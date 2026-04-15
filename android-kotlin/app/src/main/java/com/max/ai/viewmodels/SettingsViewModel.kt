package com.max.ai.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.max.ai.AppSettings
import com.max.ai.services.AuthRepository
import com.max.ai.services.StorageRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class SettingsUiState(
    val apiKey: String = "",
    val apiKeyVisible: Boolean = false,
    val profileName: String = "",
    val profileEmail: String = "",
    val voiceEnabled: Boolean = false,
    val colorScheme: String = "system",   // "system" | "light" | "dark"
    val isSaved: Boolean = false,
    val isSignedOut: Boolean = false,
    val error: String? = null
)

class SettingsViewModel(
    private val storageRepository: StorageRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        loadSettings()
    }

    // ─── Load ─────────────────────────────────────────────────────────────────

    private fun loadSettings() {
        val settings = storageRepository.getSettings()
        val user = authRepository.getUser()
        _uiState.update {
            it.copy(
                apiKey       = settings.apiKey,
                profileName  = settings.userName.ifBlank { user?.name ?: "" },
                profileEmail = user?.email ?: "",
                voiceEnabled = settings.voiceEnabled,
                colorScheme  = settings.colorScheme
            )
        }
    }

    // ─── Field updates ────────────────────────────────────────────────────────

    fun onApiKeyChanged(value: String)     = _uiState.update { it.copy(apiKey = value, isSaved = false, error = null) }
    fun onProfileNameChanged(value: String) = _uiState.update { it.copy(profileName = value, isSaved = false) }
    fun onVoiceToggled(enabled: Boolean)   = _uiState.update { it.copy(voiceEnabled = enabled, isSaved = false) }
    fun onColorSchemeChanged(scheme: String) = _uiState.update { it.copy(colorScheme = scheme, isSaved = false) }
    fun toggleApiKeyVisibility()           = _uiState.update { it.copy(apiKeyVisible = !it.apiKeyVisible) }

    // ─── Save ─────────────────────────────────────────────────────────────────

    fun saveSettings() {
        val state = _uiState.value
        if (state.apiKey.isBlank()) {
            _uiState.update { it.copy(error = "API key cannot be empty") }
            return
        }
        viewModelScope.launch {
            val settings = AppSettings(
                apiKey       = state.apiKey.trim(),
                assistantName = "Max",
                voiceEnabled = state.voiceEnabled,
                userName     = state.profileName.trim(),
                colorScheme  = state.colorScheme
            )
            storageRepository.saveSettings(settings)
            _uiState.update { it.copy(isSaved = true, error = null) }
        }
    }

    // ─── Actions ──────────────────────────────────────────────────────────────

    fun clearHistory() {
        storageRepository.clearMessages()
    }

    fun signOut() {
        viewModelScope.launch {
            authRepository.signOut()
            _uiState.update { it.copy(isSignedOut = true) }
        }
    }

    // ─── Factory ──────────────────────────────────────────────────────────────

    class Factory(
        private val storageRepository: StorageRepository,
        private val authRepository: AuthRepository
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(SettingsViewModel::class.java)) {
                return SettingsViewModel(storageRepository, authRepository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel: ${modelClass.name}")
        }
    }
}

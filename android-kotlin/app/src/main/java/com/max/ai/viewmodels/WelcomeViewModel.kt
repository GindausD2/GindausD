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

data class WelcomeUiState(
    val currentPage: Int = 1,           // 0=Login, 1=Welcome, 2=SignUp
    val email: String = "",
    val password: String = "",
    val signUpEmail: String = "",
    val signUpName: String = "",
    val signUpPassword: String = "",
    val isEmailSignUpExpanded: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null,
    val isAuthenticated: Boolean = false,
    // Demo onboarding
    val showDemoOnboarding: Boolean = false,
    val demoName: String = "",
    val demoGender: String = "prefer_not_to_say", // "male" | "female" | "prefer_not_to_say"
    val demoVoice: String = "female"              // "female" | "male"
)

class WelcomeViewModel(
    private val authRepository: AuthRepository,
    private val storageRepository: StorageRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(WelcomeUiState())
    val uiState: StateFlow<WelcomeUiState> = _uiState.asStateFlow()

    // ─── Page navigation ──────────────────────────────────────────────────────

    fun navigateToPage(page: Int) {
        _uiState.update { it.copy(currentPage = page.coerceIn(0, 2), error = null) }
    }

    // ─── Login form ───────────────────────────────────────────────────────────

    fun onEmailChanged(value: String) = _uiState.update { it.copy(email = value, error = null) }
    fun onPasswordChanged(value: String) = _uiState.update { it.copy(password = value, error = null) }

    fun login() {
        val state = _uiState.value
        if (state.email.isBlank()) {
            _uiState.update { it.copy(error = "Please enter your email") }
            return
        }
        if (state.password.isBlank()) {
            _uiState.update { it.copy(error = "Please enter your password") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            runCatching {
                authRepository.signIn(state.email.trim())
                _uiState.update { it.copy(isAuthenticated = true, isLoading = false) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message ?: "Login failed") }
            }
        }
    }

    // ─── Sign up form ─────────────────────────────────────────────────────────

    fun onSignUpNameChanged(value: String) = _uiState.update { it.copy(signUpName = value, error = null) }
    fun onSignUpEmailChanged(value: String) = _uiState.update { it.copy(signUpEmail = value, error = null) }
    fun onSignUpPasswordChanged(value: String) = _uiState.update { it.copy(signUpPassword = value, error = null) }

    fun toggleEmailSignUp() = _uiState.update { it.copy(isEmailSignUpExpanded = !it.isEmailSignUpExpanded, error = null) }

    fun signUpWithEmail() {
        val state = _uiState.value
        if (state.signUpName.isBlank()) {
            _uiState.update { it.copy(error = "Please enter your name") }
            return
        }
        if (state.signUpEmail.isBlank()) {
            _uiState.update { it.copy(error = "Please enter your email") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            runCatching {
                authRepository.signUp(state.signUpName.trim(), state.signUpEmail.trim())
                _uiState.update { it.copy(isAuthenticated = true, isLoading = false) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message ?: "Sign up failed") }
            }
        }
    }

    fun signUpWithGoogle() {
        // Google sign-in would require Google Play Services integration.
        // For now, treat as demo sign-in.
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            runCatching {
                authRepository.signUp("Google User", "google@example.com")
                _uiState.update { it.copy(isAuthenticated = true, isLoading = false) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message ?: "Google sign-in failed") }
            }
        }
    }

    // ─── Demo onboarding ──────────────────────────────────────────────────────

    fun startDemoOnboarding() = _uiState.update { it.copy(showDemoOnboarding = true) }
    fun dismissDemoOnboarding() = _uiState.update { it.copy(showDemoOnboarding = false) }
    fun onDemoNameChanged(v: String) = _uiState.update { it.copy(demoName = v) }
    fun onDemoGenderChanged(v: String) = _uiState.update { it.copy(demoGender = v) }
    fun onDemoVoiceChanged(v: String) = _uiState.update { it.copy(demoVoice = v) }

    fun finishDemo() {
        viewModelScope.launch {
            val state = _uiState.value
            val name = state.demoName.ifBlank { "Guest" }
            authRepository.startDemo(name)
            val settings = storageRepository.getSettings()
            storageRepository.saveSettings(settings.copy(userName = name, preferredVoice = state.demoVoice))
            _uiState.update { it.copy(isAuthenticated = true, showDemoOnboarding = false) }
        }
    }

    // ─── Factory ──────────────────────────────────────────────────────────────

    class Factory(
        private val authRepository: AuthRepository,
        private val storageRepository: StorageRepository
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(WelcomeViewModel::class.java)) {
                return WelcomeViewModel(authRepository, storageRepository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel: ${modelClass.name}")
        }
    }
}

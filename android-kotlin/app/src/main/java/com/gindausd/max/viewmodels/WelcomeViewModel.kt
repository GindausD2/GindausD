package com.gindausd.max.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.gindausd.max.data.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed class AuthState {
    object Idle : AuthState()
    object Loading : AuthState()
    data class Success(val isNewUser: Boolean = false) : AuthState()
    data class Error(val message: String) : AuthState()
}

class WelcomeViewModel(application: Application) : AndroidViewModel(application) {

    private val authRepo = AuthRepository.getInstance(application)

    private val _authState = MutableStateFlow<AuthState>(AuthState.Idle)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    fun signIn(email: String, password: String) {
        if (email.isBlank() || password.isBlank()) {
            _authState.value = AuthState.Error("Email and password are required.")
            return
        }

        viewModelScope.launch {
            _authState.value = AuthState.Loading
            val result = authRepo.signIn(email, password)
            _authState.value = if (result.isSuccess) {
                AuthState.Success(isNewUser = false)
            } else {
                AuthState.Error(result.exceptionOrNull()?.message ?: "Sign in failed.")
            }
        }
    }

    fun signUp(email: String, password: String, name: String) {
        if (email.isBlank() || password.isBlank()) {
            _authState.value = AuthState.Error("Email and password are required.")
            return
        }
        if (name.isBlank()) {
            _authState.value = AuthState.Error("Name is required.")
            return
        }

        viewModelScope.launch {
            _authState.value = AuthState.Loading
            val result = authRepo.signUp(email, password, name)
            _authState.value = if (result.isSuccess) {
                AuthState.Success(isNewUser = true)
            } else {
                AuthState.Error(result.exceptionOrNull()?.message ?: "Sign up failed.")
            }
        }
    }

    fun startDemo() {
        viewModelScope.launch {
            _authState.value = AuthState.Loading
            try {
                authRepo.startDemo()
                _authState.value = AuthState.Success(isNewUser = true)
            } catch (e: Exception) {
                _authState.value = AuthState.Error(e.message ?: "Failed to start demo.")
            }
        }
    }

    fun clearError() {
        _authState.value = AuthState.Idle
    }
}

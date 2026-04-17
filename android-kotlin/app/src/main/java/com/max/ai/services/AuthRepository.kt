package com.max.ai.services

import android.content.Context
import android.content.SharedPreferences
import com.max.ai.AuthUser
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class AuthRepository(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private val _userFlow = MutableStateFlow<AuthUser?>(getUser())
    val userFlow: StateFlow<AuthUser?> = _userFlow.asStateFlow()

    // ─── Public API ───────────────────────────────────────────────────────────

    fun signIn(email: String) {
        val user = AuthUser(email = email, isDemo = false)
        persist(user)
    }

    fun signUp(name: String, email: String) {
        val user = AuthUser(name = name, email = email, isDemo = false)
        persist(user)
    }

    fun startDemo(name: String = "Demo User") {
        val user = AuthUser(name = name.ifBlank { "Demo User" }, isDemo = true)
        persist(user)
    }

    fun signOut() {
        prefs.edit().remove(KEY_AUTH_USER).apply()
        _userFlow.value = null
    }

    fun getUser(): AuthUser? {
        val raw = prefs.getString(KEY_AUTH_USER, null) ?: return null
        return runCatching { json.decodeFromString<AuthUser>(raw) }.getOrNull()
    }

    fun isAuthenticated(): Boolean = getUser() != null

    // ─── Private ──────────────────────────────────────────────────────────────

    private fun persist(user: AuthUser) {
        val encoded = json.encodeToString(user)
        prefs.edit().putString(KEY_AUTH_USER, encoded).apply()
        _userFlow.value = user
    }

    companion object {
        private const val PREFS_NAME = "max_ai_prefs"
        private const val KEY_AUTH_USER = "max:auth_user"
    }
}

package com.gindausd.max.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.gindausd.max.AuthUser
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.authDataStore: DataStore<Preferences> by preferencesDataStore(name = "max_auth")

class AuthRepository private constructor(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val scope = CoroutineScope(Dispatchers.IO)

    private val _currentUser = MutableStateFlow<AuthUser?>(null)
    val currentUser: StateFlow<AuthUser?> = _currentUser.asStateFlow()

    private var _demoStartDate: Long = 0L
    val demoStartDate: Long get() = _demoStartDate

    val isDemoExpired: Boolean
        get() {
            val user = _currentUser.value ?: return false
            if (user.isDemo != true) return false
            val elapsed = System.currentTimeMillis() - _demoStartDate
            return elapsed > SEVEN_DAYS_MS
        }

    val demoTrialDaysRemaining: Int
        get() {
            if (_currentUser.value?.isDemo != true) return 0
            val elapsed = System.currentTimeMillis() - _demoStartDate
            val remaining = SEVEN_DAYS_MS - elapsed
            return maxOf(0, (remaining / DAY_MS).toInt())
        }

    init {
        scope.launch {
            loadPersistedUser()
        }
    }

    private suspend fun loadPersistedUser() {
        val prefs = context.authDataStore.data.firstOrNull() ?: return
        val userJson = prefs[KEY_USER]
        val demoDate = prefs[KEY_DEMO_START] ?: 0L
        _demoStartDate = demoDate
        if (userJson != null) {
            _currentUser.value = try {
                json.decodeFromString(userJson)
            } catch (e: Exception) {
                null
            }
        }
    }

    suspend fun startDemo() {
        val user = AuthUser(name = "Demo User", email = null, isDemo = true)
        _currentUser.value = user
        _demoStartDate = System.currentTimeMillis()
        context.authDataStore.edit { prefs ->
            prefs[KEY_USER] = json.encodeToString(user)
            prefs[KEY_DEMO_START] = _demoStartDate
        }
    }

    suspend fun signOut() {
        _currentUser.value = null
        context.authDataStore.edit { prefs ->
            prefs.remove(KEY_USER)
            prefs.remove(KEY_DEMO_START)
        }
    }

    suspend fun expireDemoIfNeeded() {
        if (isDemoExpired) {
            signOut()
        }
    }

    // Supabase integration: replace stub body with real Supabase auth call
    suspend fun signIn(email: String, password: String): Result<AuthUser> {
        return try {
            // TODO: Replace with Supabase auth: supabaseClient.auth.signInWith(Email) { ... }
            val user = AuthUser(name = email.substringBefore("@"), email = email, isDemo = false)
            _currentUser.value = user
            context.authDataStore.edit { prefs ->
                prefs[KEY_USER] = json.encodeToString(user)
            }
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Supabase integration: replace stub body with real Supabase sign-up call
    suspend fun signUp(email: String, password: String, name: String): Result<AuthUser> {
        return try {
            // TODO: Replace with Supabase auth: supabaseClient.auth.signUpWith(Email) { ... }
            val user = AuthUser(name = name, email = email, isDemo = false)
            _currentUser.value = user
            context.authDataStore.edit { prefs ->
                prefs[KEY_USER] = json.encodeToString(user)
            }
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    companion object {
        private val KEY_USER = stringPreferencesKey("auth_user")
        private val KEY_DEMO_START = longPreferencesKey("demo_start_date")
        private const val SEVEN_DAYS_MS = 7L * 24 * 60 * 60 * 1000
        private const val DAY_MS = 24L * 60 * 60 * 1000

        @Volatile private var INSTANCE: AuthRepository? = null
        fun getInstance(context: Context): AuthRepository =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: AuthRepository(context.applicationContext).also { INSTANCE = it }
            }
    }
}

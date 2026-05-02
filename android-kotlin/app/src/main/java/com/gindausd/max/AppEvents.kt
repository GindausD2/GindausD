package com.gindausd.max

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

// Singleton event bus for cross-component signals (widget tap, tile tap → start listening)
object AppEvents {
    private val _startListening = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val startListening: SharedFlow<Unit> = _startListening.asSharedFlow()

    fun emitStartListening() {
        _startListening.tryEmit(Unit)
    }
}

package com.gindausd.max

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

object AppEvents {
    private val _startListening = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val startListening: SharedFlow<Unit> = _startListening.asSharedFlow()

    fun emitStartListening() { _startListening.tryEmit(Unit) }

    private val _startBriefing = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val startBriefing: SharedFlow<Unit> = _startBriefing.asSharedFlow()

    fun emitStartBriefing() { _startBriefing.tryEmit(Unit) }
}

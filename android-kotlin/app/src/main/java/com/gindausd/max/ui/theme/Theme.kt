package com.gindausd.max.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val MaxDarkColorScheme = darkColorScheme(
    primary = OrangePrimary,
    onPrimary = Color.White,
    primaryContainer = Color(0xFF3D2000),
    onPrimaryContainer = Color(0xFFFFDDB6),
    secondary = OrangeSecondary,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFF2E1A00),
    onSecondaryContainer = Color(0xFFFFDDB6),
    tertiary = OrangeTertiary,
    onTertiary = Color.White,
    background = BackgroundDark,
    onBackground = OnSurfaceWhite,
    surface = SurfaceDark,
    onSurface = OnSurfaceWhite,
    surfaceVariant = SurfaceVariantDark,
    onSurfaceVariant = OnSurfaceDim,
    error = ErrorRed,
    onError = Color.White,
    outline = Color(0xFF5C4A30),
    outlineVariant = Color(0xFF3D2E18)
)

@Composable
fun MaxTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MaxDarkColorScheme,
        content = content
    )
}

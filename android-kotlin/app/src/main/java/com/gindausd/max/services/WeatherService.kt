package com.gindausd.max.services

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.URLEncoder
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

class WeatherService private constructor() {

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    suspend fun getWeather(context: Context, locationName: String? = null): String =
        withContext(Dispatchers.IO) {
            try {
                val (lat, lon, resolvedName) = if (!locationName.isNullOrBlank()) {
                    geocode(locationName)
                        ?: return@withContext "Could not find location \"$locationName\"."
                } else {
                    getDeviceCoords(context)
                        ?: return@withContext "Location unavailable. Try asking like \"what's the weather in London?\""
                }
                fetchAndFormat(lat, lon, resolvedName)
            } catch (e: Exception) {
                "Weather unavailable: ${e.message}"
            }
        }

    private fun getDeviceCoords(context: Context): Triple<Double, Double, String>? {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) return null

        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        for (provider in lm.getProviders(true)) {
            val loc = try { lm.getLastKnownLocation(provider) } catch (e: Exception) { null }
            if (loc != null) return Triple(loc.latitude, loc.longitude, "your location")
        }
        return null
    }

    private suspend fun geocode(name: String): Triple<Double, Double, String>? =
        withContext(Dispatchers.IO) {
            val encoded = URLEncoder.encode(name, "UTF-8")
            val url = "https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=1&language=en&format=json"
            val body = client.newCall(Request.Builder().url(url).build())
                .execute().body?.string() ?: return@withContext null
            val results = JSONObject(body).optJSONArray("results") ?: return@withContext null
            if (results.length() == 0) return@withContext null
            val first = results.getJSONObject(0)
            Triple(
                first.getDouble("latitude"),
                first.getDouble("longitude"),
                buildString {
                    append(first.optString("name", name))
                    val country = first.optString("country_code", "")
                    if (country.isNotBlank()) append(", $country")
                }
            )
        }

    private suspend fun fetchAndFormat(lat: Double, lon: Double, locationName: String): String {
        val useFahrenheit = Locale.getDefault().country == "US"
        val tempUnit = if (useFahrenheit) "fahrenheit" else "celsius"
        val windUnit = if (useFahrenheit) "mph" else "kmh"
        val unit = if (useFahrenheit) "°F" else "°C"
        val windLabel = if (useFahrenheit) "mph" else "km/h"

        val url = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=$lat&longitude=$lon" +
            "&current=temperature_2m,apparent_temperature,weathercode,windspeed_10m,relativehumidity_2m" +
            "&daily=temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum" +
            "&forecast_days=7&timezone=auto" +
            "&temperature_unit=$tempUnit&wind_speed_unit=$windUnit"

        val body = client.newCall(Request.Builder().url(url).build())
            .execute().body?.string() ?: return "No weather data returned."
        val json = JSONObject(body)

        val cur = json.getJSONObject("current")
        val temp = cur.getDouble("temperature_2m").toInt()
        val feels = cur.getDouble("apparent_temperature").toInt()
        val code = cur.getInt("weathercode")
        val wind = cur.getDouble("windspeed_10m").toInt()
        val humidity = cur.getInt("relativehumidity_2m")

        val daily = json.getJSONObject("daily")
        val times = daily.getJSONArray("time")
        val maxT = daily.getJSONArray("temperature_2m_max")
        val minT = daily.getJSONArray("temperature_2m_min")
        val codes = daily.getJSONArray("weathercode")
        val precip = daily.getJSONArray("precipitation_sum")

        return buildString {
            appendLine("Weather for $locationName:")
            appendLine("${weatherDescription(code)} — $temp$unit (feels like $feels$unit)")
            appendLine("Humidity $humidity% · Wind $wind $windLabel")
            appendLine()
            appendLine("7-Day Forecast:")

            val dayNames = arrayOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
            for (i in 0 until minOf(7, times.length())) {
                val label = when (i) {
                    0 -> "Today    "
                    1 -> "Tomorrow "
                    else -> {
                        val cal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, i) }
                        "${dayNames[cal.get(Calendar.DAY_OF_WEEK) - 1]}      "
                    }
                }.take(9)
                val hi = maxT.getDouble(i).toInt()
                val lo = minT.getDouble(i).toInt()
                val rain = precip.getDouble(i)
                val rainStr = if (rain >= 0.5) " · ${String.format("%.1f", rain)}mm" else ""
                appendLine("$label ${weatherDescription(codes.getInt(i))}  $lo–$hi$unit$rainStr")
            }
        }.trimEnd()
    }

    private fun weatherDescription(code: Int): String = when (code) {
        0 -> "Clear sky ☀️"
        1 -> "Mainly clear 🌤"
        2 -> "Partly cloudy ⛅️"
        3 -> "Overcast ☁️"
        45, 48 -> "Foggy 🌫"
        51, 53 -> "Light drizzle 🌦"
        55 -> "Heavy drizzle 🌧"
        61 -> "Light rain 🌦"
        63 -> "Moderate rain 🌧"
        65 -> "Heavy rain 🌧"
        71, 73 -> "Light snow 🌨"
        75 -> "Heavy snow ❄️"
        77 -> "Snow grains 🌨"
        80 -> "Light showers 🌦"
        81, 82 -> "Rain showers 🌧"
        85, 86 -> "Snow showers 🌨"
        95 -> "Thunderstorm ⛈"
        96, 99 -> "Thunderstorm with hail ⛈"
        else -> "Mixed conditions"
    }

    companion object {
        @Volatile private var INSTANCE: WeatherService? = null
        fun getInstance(): WeatherService =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: WeatherService().also { INSTANCE = it }
            }
    }
}

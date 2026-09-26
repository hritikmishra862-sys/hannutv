package com.horis.cncverse

import android.content.Context
import android.util.Log
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import org.json.JSONObject
import java.net.URLEncoder
import java.util.Base64
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

object NetmirrorThrottler {
    private const val MIN_INTERVAL_MS = 1200L
    private var lastRequest = 0L
    private val mutex = Mutex()

    suspend fun throttle() {
        mutex.withLock {
            val now = System.currentTimeMillis()
            val wait = MIN_INTERVAL_MS - (now - lastRequest)
            if (wait > 0) delay(wait)
            lastRequest = System.currentTimeMillis()
        }
    }
}

object Utils {
    private const val TAG = "CNCVerseUtils"
    const val USER_AGENT = "Mozilla/5.0 (Linux; Android 13; Pixel 5 Build/TQ3A.230901.001; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/144.0.7559.132 Safari/537.36 /OS.Gatu v3.0"

    val baseClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    val newTvBaseHeaders = mapOf(
        "Cache-Control" to "no-cache, no-store, must-revalidate",
        "Pragma" to "no-cache",
        "Expires" to "0",
        "X-Requested-With" to "NetmirrorNewTV v1.0",
        "User-Agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0 /OS.GatuNewTV v1.0",
        "Accept" to "application/json, text/plain, */*"
    )

    val newTvDomains = listOf(
        "aHR0cHM6Ly9tb2JpbGVkZXRlY3RzLmNvbQ==",
        "aHR0cHM6Ly9tb2JpbGVkZXRlY3QuYXBw",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LmFydA==",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LmNj",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LmNsaWNr",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0Lmluaw==",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LmxpdmU=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LnBybw==",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LnNob3A=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LnNpdGU=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LnNwYWNl",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LnN0b3Jl",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0LnZpcA==",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0Lndpa2k=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0Lnh5eg==",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy5hcnQ=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy5jYw==",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy5pbmZv",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy5pbms=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy5saXZl",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy5wcm8=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy5zdG9yZQ==",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy50b3A=",
        "aHR0cHM6Ly9tb2JpZGV0ZWN0cy54eXo="
    )

    private var resolvedApiUrl: String = ""

    fun decodeBase64(value: String): String {
        return try {
            String(Base64.getDecoder().decode(value))
        } catch (e: Exception) {
            try {
                String(android.util.Base64.decode(value, android.util.Base64.DEFAULT))
            } catch (_: Exception) {
                value
            }
        }
    }

    suspend fun resolveApiUrl(): String {
        if (resolvedApiUrl.isNotBlank()) return resolvedApiUrl
        val (saved, savedTs) = NetflixMirrorStorage.getApiBase()
        if (!saved.isNullOrBlank() && System.currentTimeMillis() - savedTs < 86_400_000L) {
            resolvedApiUrl = saved
            return resolvedApiUrl
        }
        for (encoded in newTvDomains) {
            val base = decodeBase64(encoded).trimEnd('/')
            try {
                NetmirrorThrottler.throttle()
                val responseText = getText("$base/checknewtv.php", newTvBaseHeaders)
                val json = parseJson(responseText)
                val tokenHash = json?.optString("token_hash")
                if (!tokenHash.isNullOrBlank()) {
                    resolvedApiUrl = decodeBase64(tokenHash).trimEnd('/')
                    NetflixMirrorStorage.saveApiBase(resolvedApiUrl)
                    return resolvedApiUrl
                }
            } catch (_: Exception) {}
        }
        return "https://net52.cc"
    }

    fun buildNewTvHeaders(ott: String, extra: Map<String, String> = emptyMap()): Map<String, String> {
        val result = newTvBaseHeaders.toMutableMap()
        result["Ott"] = ott
        extra.forEach { (key, value) -> result[key] = value }
        return result
    }

    suspend fun bypass(mainUrl: String): String {
        val (savedCookie, savedTimestamp) = NetflixMirrorStorage.getCookie()
        if (!savedCookie.isNullOrEmpty() && System.currentTimeMillis() - savedTimestamp < 54_000_000) {
            return savedCookie
        }

        val newCookie = try {
            val headers = mapOf(
                "Accept" to "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
                "Accept-Language" to "en-US,en;q=0.9",
                "Connection" to "keep-alive",
                "Content-Type" to "application/x-www-form-urlencoded",
                "Origin" to "https://net77.cc",
                "Referer" to "https://net77.cc/verify2",
                "User-Agent" to USER_AGENT
            )
            val formBody = FormBody.Builder()
                .add("g-recaptcha-response", UUID.randomUUID().toString())
                .build()

            val noRedirectClient = baseClient.newBuilder()
                .followRedirects(false)
                .followSslRedirects(false)
                .build()

            val requestBuilder = Request.Builder().url("https://net52.cc/verify.php").post(formBody)
            headers.forEach { (k, v) -> requestBuilder.addHeader(k, v) }

            noRedirectClient.newCall(requestBuilder.build()).execute().use { response ->
                response.headers.values("Set-Cookie")
                    .firstOrNull { it.startsWith("t_hash_t=") }
                    ?.substringAfter("t_hash_t=")
                    ?.substringBefore(";")
                    .orEmpty()
            }
        } catch (e: Exception) {
            NetflixMirrorStorage.clearCookie()
            ""
        }

        if (newCookie.isNotEmpty()) {
            NetflixMirrorStorage.saveCookie(newCookie)
        }
        return newCookie
    }

    fun get(url: String, headers: Map<String, String> = emptyMap(), cookies: Map<String, String> = emptyMap()): Response {
        val requestBuilder = Request.Builder().url(url)
        headers.forEach { (k, v) -> requestBuilder.addHeader(k, v) }
        if (cookies.isNotEmpty()) {
            val cookieStr = cookies.entries.joinToString("; ") { "${it.key}=${it.value}" }
            requestBuilder.addHeader("Cookie", cookieStr)
        }
        return baseClient.newCall(requestBuilder.build()).execute()
    }

    fun getText(url: String, headers: Map<String, String> = emptyMap(), cookies: Map<String, String> = emptyMap()): String {
        return try {
            get(url, headers, cookies).use { it.body?.string() ?: "" }
        } catch (e: Exception) {
            Log.e(TAG, "getText failed: $url -> ${e.localizedMessage}")
            ""
        }
    }

    fun post(url: String, data: Map<String, String> = emptyMap(), headers: Map<String, String> = emptyMap(), cookies: Map<String, String> = emptyMap()): Response {
        val formBuilder = FormBody.Builder()
        data.forEach { (k, v) -> formBuilder.add(k, v) }

        val requestBuilder = Request.Builder().url(url).post(formBuilder.build())
        headers.forEach { (k, v) -> requestBuilder.addHeader(k, v) }
        if (cookies.isNotEmpty()) {
            val cookieStr = cookies.entries.joinToString("; ") { "${it.key}=${it.value}" }
            requestBuilder.addHeader("Cookie", cookieStr)
        }
        return baseClient.newCall(requestBuilder.build()).execute()
    }

    fun postText(url: String, data: Map<String, String> = emptyMap(), headers: Map<String, String> = emptyMap(), cookies: Map<String, String> = emptyMap()): String {
        return try {
            post(url, data, headers, cookies).use { it.body?.string() ?: "" }
        } catch (e: Exception) {
            Log.e(TAG, "postText failed: $url -> ${e.localizedMessage}")
            ""
        }
    }

    fun parseJson(jsonStr: String): JSONObject? {
        return try {
            if (jsonStr.isBlank()) null else JSONObject(jsonStr)
        } catch (e: Exception) {
            null
        }
    }

    fun encode(query: String): String {
        return try {
            URLEncoder.encode(query, "UTF-8")
        } catch (e: Exception) {
            query
        }
    }
}
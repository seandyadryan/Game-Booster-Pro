package com.deploydulupulangnanti.gameboosterpro

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.SystemClock
import java.net.InetSocketAddress

class NetworkDiagnostics(context: Context) {
    private val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    fun check(): Map<String, Any?> {
        val network = manager.activeNetwork ?: error("No active network. Connect to Wi-Fi or mobile data and try again.")
        val capabilities = manager.getNetworkCapabilities(network)
            ?: error("The active network is unavailable. Try again.")
        check(capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            "This network has no Internet connection."
        }
        val networkType = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile data"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            else -> "Active network"
        }
        val samples = mutableListOf<Double?>()
        repeat(5) { index ->
            check(manager.activeNetwork == network) { "Your network changed during the check. Run a new check." }
            val elapsed = runCatching {
                network.socketFactory.createSocket().use { socket ->
                    val start = SystemClock.elapsedRealtimeNanos()
                    socket.connect(InetSocketAddress("1.1.1.1", 443), 2000)
                    (SystemClock.elapsedRealtimeNanos() - start) / 1_000_000.0
                }
            }.getOrNull()
            samples.add(elapsed)
            if (index < 4) Thread.sleep(250)
        }
        check(manager.activeNetwork == network) { "Your network changed during the check. Run a new check." }
        return mapOf(
            "networkType" to networkType,
            "endpoint" to "1.1.1.1:443"
        ) + summarizeLatency(samples)
    }
}

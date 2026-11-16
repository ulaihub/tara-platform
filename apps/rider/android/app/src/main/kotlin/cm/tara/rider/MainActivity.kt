package cm.tara.rider

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// FragmentActivity : demandée par la fenêtre de l'empreinte digitale (local_auth).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * Canaux des notifications envoyées par le serveur (`channel_id`), chacun avec un son
     * de la marque. Recréer un canal existant ne change rien : l'utilisateur garde ses
     * réglages. Android 8 minimum (minSdk 26) : les canaux existent toujours.
     */
    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        fun channel(id: String, name: Int, importance: Int, sound: String) =
            NotificationChannel(id, getString(name), importance).apply {
                setSound(Uri.parse("android.resource://$packageName/raw/$sound"), attributes)
                enableVibration(true)
            }

        manager.createNotificationChannels(
            listOf(
                channel("offers", R.string.channel_offers, NotificationManager.IMPORTANCE_HIGH, "tara_offer"),
                channel("orders", R.string.channel_orders, NotificationManager.IMPORTANCE_DEFAULT, "tara_received"),
                channel("money", R.string.channel_money, NotificationManager.IMPORTANCE_DEFAULT, "tara_cash"),
            ),
        )
    }
}

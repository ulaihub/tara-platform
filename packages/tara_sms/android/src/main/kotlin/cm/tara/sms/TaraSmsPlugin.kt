package cm.tara.sms

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Base64
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

/**
 * Lecture du code SMS, sans permission de lecture des SMS :
 * - `listen` sans accord : SMS Retriever, le SMS porte l'empreinte de l'app (aucun geste) ;
 * - `listen` avec accord : SMS User Consent, Android montre le SMS et demande « Autoriser ».
 * `appHash` donne l'empreinte de l'app, à envoyer au serveur. Une seule attente à la fois.
 */
class TaraSmsPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var receiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(flutter: FlutterPlugin.FlutterPluginBinding) {
        context = flutter.applicationContext
        channel = MethodChannel(flutter.binaryMessenger, "tara_sms")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutter: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        finish(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "appHash" -> result.success(appHash())
            "listen" -> listen(call.argument<Boolean>("consent") == true, result)
            "cancel" -> {
                finish(null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Empreinte de 11 caractères calculée comme Google (AppSignatureHelper) : nom du paquet et
     * certificat de signature, SHA-256, 9 premiers octets en base64. Elle change avec la clé de
     * signature : celle des APK de test diffère de celle de Google Play.
     */
    @Suppress("DEPRECATION")
    private fun appHash(): String? =
        try {
            val info = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
            info.signatures?.firstOrNull()?.let { signature ->
                val digest = MessageDigest.getInstance("SHA-256")
                    .digest("${context.packageName} ${signature.toCharsString()}".toByteArray(StandardCharsets.UTF_8))
                Base64.encodeToString(digest.copyOfRange(0, 9), Base64.NO_PADDING or Base64.NO_WRAP).substring(0, 11)
            }
        } catch (error: Exception) {
            null
        }

    /** Attend le prochain SMS (5 minutes au plus) ; renvoie son texte, ou null. */
    private fun listen(consent: Boolean, result: MethodChannel.Result) {
        finish(null)
        pending = result
        val client = SmsRetriever.getClient(context)
        val started = if (consent) client.startSmsUserConsent(null) else client.startSmsRetriever()
        started.addOnFailureListener { finish(null) }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                val extras = intent.extras ?: return finish(null)
                if (parcelable(extras, SmsRetriever.EXTRA_STATUS, Status::class.java)?.statusCode != CommonStatusCodes.SUCCESS) {
                    return finish(null)
                }
                if (!consent) return finish(extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE))
                val ask = parcelable(extras, SmsRetriever.EXTRA_CONSENT_INTENT, Intent::class.java)
                val activity = binding?.activity
                if (ask == null || activity == null || !fromGoogle(ask)) return finish(null)
                unregister()
                try {
                    activity.startActivityForResult(ask, CONSENT_REQUEST)
                } catch (error: Exception) {
                    finish(null)
                }
            }
        }
        this.receiver = receiver
        val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, SmsRetriever.SEND_PERMISSION, null, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter, SmsRetriever.SEND_PERMISSION, null)
        }
    }

    /**
     * La demande d'accord doit ouvrir un écran des services Google, sans droit d'accès à des
     * fichiers : une autre app ne peut pas se faire passer pour elle.
     */
    private fun fromGoogle(intent: Intent): Boolean {
        val target = intent.resolveActivity(context.packageManager) ?: return false
        val grants = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        return target.packageName == "com.google.android.gms" && intent.flags and grants == 0
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != CONSENT_REQUEST) return false
        finish(if (resultCode == Activity.RESULT_OK) data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE) else null)
        return true
    }

    private fun unregister() {
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (error: IllegalArgumentException) {
                // Déjà retiré.
            }
        }
        receiver = null
    }

    private fun finish(message: String?) {
        unregister()
        pending?.success(message)
        pending = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
    }

    private companion object {
        const val CONSENT_REQUEST = 4721

        fun <T> parcelable(extras: Bundle, key: String, type: Class<T>): T? =
            if (Build.VERSION.SDK_INT >= 33) {
                extras.getParcelable(key, type)
            } else {
                @Suppress("DEPRECATION")
                type.cast(extras.get(key))
            }
    }
}

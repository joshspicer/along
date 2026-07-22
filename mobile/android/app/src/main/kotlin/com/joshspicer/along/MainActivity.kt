package com.joshspicer.along

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialCancellationException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var credentialManager: CredentialManager
    private var notificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        credentialManager = CredentialManager.create(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.joshspicer.along/passkeys",
        ).setMethodCallHandler(::handlePasskey)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.joshspicer.along/notifications",
        ).setMethodCallHandler(::handleNotifications)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun handlePasskey(call: MethodCall, result: MethodChannel.Result) {
        val requestJson = call.argument<String>("requestJson")
        if (requestJson.isNullOrBlank()) {
            result.error("invalid_request", "The server passkey request was invalid.", null)
            return
        }
        scope.launch {
            try {
                when (call.method) {
                    "register" -> {
                        val response = credentialManager.createCredential(
                            context = this@MainActivity,
                            request = CreatePublicKeyCredentialRequest(requestJson),
                        )
                        val credential = response as? CreatePublicKeyCredentialResponse
                            ?: error("Unsupported registration response")
                        result.success(credential.registrationResponseJson)
                    }
                    "authenticate" -> {
                        val response = credentialManager.getCredential(
                            context = this@MainActivity,
                            request = GetCredentialRequest(
                                listOf(GetPublicKeyCredentialOption(requestJson)),
                            ),
                        )
                        val credential = response.credential as? PublicKeyCredential
                            ?: error("Unsupported authentication response")
                        result.success(credential.authenticationResponseJson)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: CreateCredentialCancellationException) {
                result.error("cancelled", "Passkey setup was cancelled.", null)
            } catch (_: GetCredentialCancellationException) {
                result.error("cancelled", "Passkey sign-in was cancelled.", null)
            } catch (error: Exception) {
                result.error(
                    "passkey_failed",
                    error.localizedMessage ?: "The passkey could not be used.",
                    null,
                )
            }
        }
    }

    private fun handleNotifications(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "request") {
            result.notImplemented()
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(mapOf("granted" to true))
            return
        }
        if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            result.success(mapOf("granted" to true))
            return
        }
        notificationResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            notificationResult?.success(
                mapOf(
                    "granted" to (
                        grantResults.isNotEmpty() &&
                            grantResults[0] == PackageManager.PERMISSION_GRANTED
                    ),
                ),
            )
            notificationResult = null
        }
    }

    private companion object {
        const val NOTIFICATION_PERMISSION_REQUEST = 4112
    }
}


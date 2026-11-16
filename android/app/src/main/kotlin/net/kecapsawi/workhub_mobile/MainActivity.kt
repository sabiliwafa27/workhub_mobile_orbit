package net.kecapsawi.workhub_mobile

import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    companion object {
        private const val PASSKEY_CHANNEL = "net.kecapsawi.workhub_mobile/passkeys"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PASSKEY_CHANNEL)
            .setMethodCallHandler { call, result ->
                val optionsJson = call.argument<String>("optionsJson")
                if (optionsJson.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "optionsJson is required", null)
                    return@setMethodCallHandler
                }

                val credentialManager = CredentialManager.create(this)
                when (call.method) {
                    "createPasskey" -> {
                        lifecycleScope.launch {
                            try {
                                val request = CreatePublicKeyCredentialRequest(optionsJson)
                                val response = credentialManager.createCredential(
                                    context = this@MainActivity,
                                    request = request,
                                )
                                val pubKeyResponse = response as? CreatePublicKeyCredentialResponse
                                if (pubKeyResponse != null) {
                                    result.success(pubKeyResponse.registrationResponseJson)
                                } else {
                                    result.error(
                                        "PASSKEY_ERROR",
                                        "Unexpected credential response type",
                                        null,
                                    )
                                }
                            } catch (e: CreateCredentialCancellationException) {
                                result.error("CANCELLED", e.message ?: "Passkey creation cancelled", null)
                            } catch (e: CreateCredentialException) {
                                result.error(
                                    "PASSKEY_ERROR",
                                    e.message ?: "Passkey creation failed (${e.type})",
                                    e.type,
                                )
                            } catch (e: Throwable) {
                                result.error(
                                    "PASSKEY_ERROR",
                                    e.message ?: e.javaClass.simpleName,
                                    null,
                                )
                            }
                        }
                    }

                    "getPasskey" -> {
                        lifecycleScope.launch {
                            try {
                                val option = GetPublicKeyCredentialOption(optionsJson)
                                val request = GetCredentialRequest(listOf(option))
                                val response = credentialManager.getCredential(
                                    context = this@MainActivity,
                                    request = request,
                                )
                                val credential = response.credential as? PublicKeyCredential
                                if (credential != null) {
                                    result.success(credential.authenticationResponseJson)
                                } else {
                                    result.error(
                                        "PASSKEY_ERROR",
                                        "Unexpected credential type",
                                        null,
                                    )
                                }
                            } catch (e: GetCredentialCancellationException) {
                                result.error("CANCELLED", e.message ?: "Passkey sign-in cancelled", null)
                            } catch (e: NoCredentialException) {
                                result.error(
                                    "NO_CREDENTIAL",
                                    "No passkey found on this device for Orbit WorkHub.",
                                    null,
                                )
                            } catch (e: GetCredentialException) {
                                result.error(
                                    "PASSKEY_ERROR",
                                    e.message ?: "Passkey sign-in failed (${e.type})",
                                    e.type,
                                )
                            } catch (e: Throwable) {
                                result.error(
                                    "PASSKEY_ERROR",
                                    e.message ?: e.javaClass.simpleName,
                                    null,
                                )
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}

package com.ofilabs.jelilabel

import android.content.Intent
import android.net.Uri
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterFragmentActivity() {
    private var sedangMemindaiBarcode = false

    private fun isHealthPermissionIntent(intent: Intent?): Boolean {
        val action = intent?.action ?: return false
        return action == "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" ||
            action == "android.intent.action.VIEW_PERMISSION_USAGE"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jelilabel/barcode")
            .setMethodCallHandler { call, result ->
                if (call.method == "pindai") {
                    pindaiBarcode(result)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jelilabel/zona_waktu")
            .setMethodCallHandler { call, result ->
                if (call.method == "zonaLokal") {
                    result.success(TimeZone.getDefault().id)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jelilabel/tautan")
            .setMethodCallHandler { call, result ->
                if (call.method == "bukaUrl") {
                    bukaUrl(call.argument<String>("url"), result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun bukaUrl(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            val uri = Uri.parse(url)
            if (uri.scheme != "https" && uri.scheme != "http") {
                result.success(false)
                return
            }
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun pindaiBarcode(result: MethodChannel.Result) {
        if (sedangMemindaiBarcode) {
            result.success(null)
            return
        }
        sedangMemindaiBarcode = true
        var sudahDibalas = false

        fun balasSukses(nilai: String?) {
            if (sudahDibalas) return
            sudahDibalas = true
            sedangMemindaiBarcode = false
            result.success(nilai)
        }

        fun balasGalat(kode: String, pesan: String?) {
            if (sudahDibalas) return
            sudahDibalas = true
            sedangMemindaiBarcode = false
            result.error(kode, pesan, null)
        }

        try {
            val options = GmsBarcodeScannerOptions.Builder()
                .setBarcodeFormats(
                    Barcode.FORMAT_EAN_13,
                    Barcode.FORMAT_EAN_8,
                    Barcode.FORMAT_UPC_A,
                    Barcode.FORMAT_UPC_E,
                )
                .build()
            val scanner = GmsBarcodeScanning.getClient(this, options)
            scanner.startScan()
                .addOnSuccessListener { barcode ->
                    balasSukses(barcode.rawValue?.takeIf { it.isNotBlank() })
                }
                .addOnCanceledListener {
                    balasSukses(null)
                }
                .addOnFailureListener { e ->
                    if (e is MlKitException && e.errorCode == MlKitException.CODE_SCANNER_CANCELLED) {
                        balasSukses(null)
                    } else {
                        balasGalat("tidak_tersedia", e.localizedMessage)
                    }
                }
        } catch (e: Exception) {
            balasGalat("tidak_tersedia", e.localizedMessage)
        }
    }

    override fun getInitialRoute(): String? {
        if (isHealthPermissionIntent(intent)) {
            return "/aktivitas/izin"
        }
        return super.getInitialRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isHealthPermissionIntent(intent)) {
            flutterEngine?.navigationChannel?.pushRouteInformation("/aktivitas/izin")
        }
    }
}

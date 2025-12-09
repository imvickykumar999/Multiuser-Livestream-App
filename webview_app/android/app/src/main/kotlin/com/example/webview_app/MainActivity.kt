package com.example.webview_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.webview_app/file_picker"
    private val REQUEST_CODE_FILE_PICKER = 1
    private var filePickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickFile") {
                filePickerResult = result
                val mimeType = call.argument<String>("mimeType") ?: "*/*"
                openFilePicker(mimeType)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openFilePicker(mimeType: String) {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = mimeType
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
        }
        startActivityForResult(Intent.createChooser(intent, "Select File"), REQUEST_CODE_FILE_PICKER)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_CODE_FILE_PICKER) {
            val uris = mutableListOf<String>()
            if (resultCode == Activity.RESULT_OK && data != null) {
                if (data.data != null) {
                    // Single file selected
                    uris.add(data.data!!.toString())
                } else if (data.clipData != null) {
                    // Multiple files selected
                    for (i in 0 until data.clipData!!.itemCount) {
                        uris.add(data.clipData!!.getItemAt(i).uri.toString())
                    }
                }
            }
            filePickerResult?.success(uris)
            filePickerResult = null
        }
    }
}

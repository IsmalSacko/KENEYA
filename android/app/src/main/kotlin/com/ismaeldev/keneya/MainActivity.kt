package com.ismaeldev.keneya

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Bord à bord sur toutes les versions d'Android, comme Android 15 le
        // fait d'office : Flutter place les écrans sous les barres système
        // et les marges (SafeArea, AppBar) s'en chargent.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}

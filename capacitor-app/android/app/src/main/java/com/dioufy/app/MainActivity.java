package com.dioufy.app;

import android.os.Bundle;
import android.webkit.ValueCallback;
import androidx.activity.OnBackPressedCallback;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Gestion native et prédictive du bouton retour Android
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                if (bridge != null && bridge.getWebView() != null) {
                    bridge.getWebView().evaluateJavascript(
                        "(function() { " +
                        "  if (window.dioufyHandleBackButton) { " +
                        "    return window.dioufyHandleBackButton(); " +
                        "  } " +
                        "  if (window.history && window.history.length > 1) { " +
                        "    window.history.back(); " +
                        "    return 'true'; " +
                        "  } " +
                        "  return 'false'; " +
                        "})()",
                        new ValueCallback<String>() {
                            @Override
                            public void onReceiveValue(String value) {
                                boolean isHandled = value != null && (value.contains("true") || "true".equalsIgnoreCase(value.replace("\"", "").trim()));
                                if (!isHandled) {
                                    // Racine de l'application : minimisation / sortie Android propre
                                    setEnabled(false);
                                    getOnBackPressedDispatcher().onBackPressed();
                                    setEnabled(true);
                                }
                            }
                        }
                    );
                } else {
                    setEnabled(false);
                    getOnBackPressedDispatcher().onBackPressed();
                    setEnabled(true);
                }
            }
        });
    }

    @Override
    protected void onNewIntent(android.content.Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
    }
}

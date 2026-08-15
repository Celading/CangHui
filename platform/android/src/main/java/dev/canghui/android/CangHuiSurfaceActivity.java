package dev.canghui.android;

import android.app.Activity;
import android.os.Bundle;
import android.view.SurfaceView;

/**
 * Minimal Activity owner for the CangHui native-surface bootstrap.
 *
 * <p>The Activity owns the Java host lifetime. Surface creation and replacement
 * remain owned by {@link CangHuiNativeSurfaceHost}'s generation-safe
 * {@code SurfaceHolder.Callback2} implementation.</p>
 */
public class CangHuiSurfaceActivity extends Activity {
    private CangHuiNativeSurfaceHost surfaceHost;
    private SurfaceView surfaceView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        surfaceHost = new CangHuiNativeSurfaceHost();
        surfaceView = new SurfaceView(this);
        setContentView(surfaceView);
    }

    @Override
    protected void onStart() {
        super.onStart();
        surfaceHost.bind(surfaceView);
    }

    @Override
    protected void onStop() {
        surfaceHost.unbind();
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        surfaceHost.close();
        surfaceHost = null;
        surfaceView = null;
        super.onDestroy();
    }

    protected final CangHuiNativeSurfaceHost surfaceHost() {
        if (surfaceHost == null) {
            throw new IllegalStateException("CangHui Android surface host is not active");
        }
        return surfaceHost;
    }

    protected final SurfaceView surfaceView() {
        if (surfaceView == null) {
            throw new IllegalStateException("CangHui Android surface view is not active");
        }
        return surfaceView;
    }
}

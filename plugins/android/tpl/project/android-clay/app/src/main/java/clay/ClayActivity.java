package clay;

import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.app.Activity;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.media.AudioManager;
import android.annotation.TargetApi;

import org.libsdl.app.SDLActivity;

public class ClayActivity extends org.libsdl.app.SDLActivity {

    private final static String CLAY_TAG = "CLAY";
    public static Activity clay_activity;
    boolean clayImmersiveFullscreen = true;

    /**
     * How long a frame can stay in the graphics driver before the drawing surface is
     * destroyed and created again (milliseconds), 0 to disable. Some drivers can block a
     * frame for good, waiting for a buffer of the window that never comes back: destroying
     * the surface makes the driver give up the blocked call, then the app pauses and resumes
     * with the same GL context, the same way it does when going to background and back.
     */
    protected long clayRenderStallRecoveryMillis = 3000;

    /** How often the watchdog checks the frame being rendered (milliseconds). */
    protected long clayRenderWatchdogPeriodMillis = 500;

    private static native long nativeRenderStallMillis();

    private final Handler clayRenderWatchdog = new Handler(Looper.getMainLooper());
    private boolean clayRenderWatchdogActive = false;
    private boolean clayRenderWatchdogAvailable = true;

    // Stall duration at the last recovery attempt: a frame still stuck afterwards is only
    // retried once it has been stuck for another full delay
    private long clayRenderStallAtLastRecovery = 0;

    private final Runnable clayRenderWatchdogCheck = new Runnable() {
        @Override
        public void run() {
            if (!clayRenderWatchdogActive) return;
            checkRenderStall();
            clayRenderWatchdog.postDelayed(this, clayRenderWatchdogPeriodMillis);
        }
    };

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.i(CLAY_TAG, "Clay / On Create");
        clay_activity = this;
        setVolumeControlStream(AudioManager.STREAM_MUSIC);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        Log.i(CLAY_TAG, "Clay / On Destroy");
    }

    @Override
    protected void onPause() {
        super.onPause();
        Log.i(CLAY_TAG, "Clay / On Pause");
        stopRenderWatchdog();
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        Log.i(CLAY_TAG, "Clay / On Restart");
    }

    @Override
    protected void onResume() {
        super.onResume();
        Log.i(CLAY_TAG, "Clay / On Resume");
        startRenderWatchdog();
    }

    @Override
    protected void onStart() {
        super.onStart();
        Log.i(CLAY_TAG, "Clay / On Start");
        
        if (clayImmersiveFullscreen && Build.VERSION.SDK_INT >= 19) {
            hideSystemUi();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        Log.i(CLAY_TAG, "Clay / On Stop");
    }

    @Override
    protected void preWindowCreate() {
        
        requestWindowFeature (Window.FEATURE_NO_TITLE);

        // Non-immersive full screen
        if (Build.VERSION.SDK_INT < 19) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
        
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);

        if (SDLActivity.mBrokenLibraries) {
           return;
        }

        if (clayImmersiveFullscreen && hasFocus) {
            if (Build.VERSION.SDK_INT >= 19) {
                hideSystemUi();
            }
        }
    }

    private void startRenderWatchdog() {

        if (clayRenderStallRecoveryMillis <= 0 || !clayRenderWatchdogAvailable || SDLActivity.mBrokenLibraries) {
            return;
        }

        if (!clayRenderWatchdogActive) {
            clayRenderWatchdogActive = true;
            clayRenderStallAtLastRecovery = 0;
            clayRenderWatchdog.postDelayed(clayRenderWatchdogCheck, clayRenderWatchdogPeriodMillis);
        }

    }

    private void stopRenderWatchdog() {

        clayRenderWatchdogActive = false;
        clayRenderWatchdog.removeCallbacks(clayRenderWatchdogCheck);

    }

    private void checkRenderStall() {

        if (mSurface == null || mCurrentNativeState != NativeState.RESUMED) {
            return;
        }

        long stalled;
        try {
            stalled = nativeRenderStallMillis();
        }
        catch (UnsatisfiedLinkError e) {
            Log.w(CLAY_TAG, "Clay / Render watchdog not available in the native library");
            clayRenderWatchdogAvailable = false;
            stopRenderWatchdog();
            return;
        }

        if (stalled < clayRenderStallRecoveryMillis) {
            clayRenderStallAtLastRecovery = 0;
            return;
        }

        if (clayRenderStallAtLastRecovery > 0 && stalled < clayRenderStallAtLastRecovery + clayRenderStallRecoveryMillis) {
            return;
        }

        clayRenderStallAtLastRecovery = stalled;
        Log.w(CLAY_TAG, "Clay / Render stalled for " + stalled + "ms, recreate the surface");
        recreateSurface();

    }

    /**
     * Destroy the drawing surface and create it again. SDL pauses the native thread when the
     * surface is destroyed and resumes it with the new surface, keeping the GL context.
     */
    protected void recreateSurface() {

        final View surface = mSurface;
        if (surface == null) return;

        surface.setVisibility(View.GONE);
        clayRenderWatchdog.postDelayed(new Runnable() {
            @Override
            public void run() {
                surface.setVisibility(View.VISIBLE);
                Log.i(CLAY_TAG, "Clay / Surface shown again after a render stall");
            }
        }, clayRenderWatchdogPeriodMillis);

    }

    @TargetApi(19)
    private void hideSystemUi() {

        View decorView = this.getWindow().getDecorView();

        decorView.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LOW_PROFILE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);

    }

}


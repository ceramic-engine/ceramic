package clay;

import android.os.Build;
import android.os.Bundle;
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


package org.snowkit.snow;

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

public class SnowActivity extends org.libsdl.app.SDLActivity {

    private final static String SNOW_TAG = "SNOW";
    public static Activity snow_activity;
    boolean snow_immersive_fullscreen = true;

    // public native void snowInit();
    // public native void snowQuit();

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.i(SNOW_TAG, ">>>>>>>>/ snow / On Create .....");
        snow_activity = this;
        setVolumeControlStream(AudioManager.STREAM_MUSIC);
        // snowInit();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        Log.i(SNOW_TAG, ">>>>>>>>/ snow / On Destroy .....");
        // snowQuit();
    }

    @Override
    protected void onPause() {
        super.onPause();
        Log.i(SNOW_TAG, ">>>>>>>>/ snow / On Pause .....");
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        Log.i(SNOW_TAG, ">>>>>>>>/ snow / On Restart .....");
    }

    @Override
    protected void onResume() {
        super.onResume();
        Log.i(SNOW_TAG, ">>>>>>>>/ snow / On Resume .....");
    }

    @Override
    protected void onStart() {
        super.onStart();
        Log.i(SNOW_TAG, ">>>>>>>>/ snow / On Start .....");
        
        if(snow_immersive_fullscreen && Build.VERSION.SDK_INT >= 19) {
            hideSystemUi();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        Log.i(SNOW_TAG, ">>>>>>>>/ snow / On Stop .....");
    }

    @Override
    protected void preWindowCreate() {
        
        requestWindowFeature (Window.FEATURE_NO_TITLE);

            //non-immersive full screen
        if(Build.VERSION.SDK_INT < 19) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
        
    } //preWindowCreate

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);

        if (SDLActivity.mBrokenLibraries) {
           return;
        }

        if(snow_immersive_fullscreen && hasFocus) {
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

} //SnowActivity


package mycompany.myapp;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;

import org.snowkit.snow.SnowActivity;

public class AppActivity extends org.snowkit.snow.SnowActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        
        super.onCreate(savedInstanceState);

    } //onCreate

    @Override
    protected String[] getLibraries() {

        return new String[] {
            "openal",
            "MyApp"
        };

    } //getLibraries

    @Override
    public void loadLibraries() {

        super.loadLibraries();

        // Initialize bind
        bind.Support.setUseNativeRunnableStack(true);
        bind.Support.setContext(this);
        bind.Support.init();

    } //loadLibraries

} //AppActivity


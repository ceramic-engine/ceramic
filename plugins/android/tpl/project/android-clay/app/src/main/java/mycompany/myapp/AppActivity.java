package mycompany.myapp;

import android.os.Bundle;
import android.system.ErrnoException;
import android.system.Os;

import clay.ClayActivity;

public class AppActivity extends clay.ClayActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {

        // See https://github.com/android/ndk/issues/495
        try {
            Os.setenv("OMP_WAIT_POLICY", "passive", true);
        } catch (ErrnoException e) {
            e.printStackTrace();
        }
        try {
            Os.setenv("KMP_BLOCKTIME", "0", true);
        } catch (ErrnoException e) {
            e.printStackTrace();
        }
        try {
            Os.setenv("GOMP_SPINCOUNT", "0", true);
        } catch (ErrnoException e) {
            e.printStackTrace();
        }

        super.onCreate(savedInstanceState);

    }

    @Override
    protected String[] getLibraries() {

        return new String[] {
            "c++_shared",
            "openal",
            "MyApp"
        };

    }

    @Override
    public void loadLibraries() {

        super.loadLibraries();

        // Initialize bind
        bind.Support.setUseNativeRunnableStack(true);
        bind.Support.setContext(this);
        bind.Support.init();

    }

}


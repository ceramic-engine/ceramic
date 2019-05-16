package ceramic.supportapp;

import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import bind.Support;
import ceramic.support.Http;

public class MainActivity extends AppCompatActivity {

    public static String TAG = "CERAMIC";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        bind.Support.setContext(this);

        // Test HTTP download
        Map<String,Object> params = new HashMap<>();
        final String url = "http://lorempixel.com/1920/1920/abstract/";
        params.put("url", url);
        Http.download(params, "someFile.jpg", new Support.Func1<String, Void>() {
            @Override
            public Void run(String downloadPath) {

                if (downloadPath != null) {
                    Log.i(TAG, "Downloaded file at path: " + downloadPath);
                    File file = new File(downloadPath);
                    Log.i(TAG, "File size: " + file.length());
                }
                else {
                    Log.e(TAG, "Failed to download file from url: " + url);
                }

                return null;
            }
        });
    }
}

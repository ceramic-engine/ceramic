package ceramic.support;

import android.util.Base64;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;

import bind.Support.*;
import ceramic.support.http.HttpRequest;

public class Http {

    /** Send HTTP request */
    public static void sendHttpRequest(final Map<String,Object> params, final Func1<Map<String,Object>,Void> done) {

        new HttpRequest(params, null, new HttpRequest.Listener() {

            @Override
            public void onComplete(final int statusCode, final String statusMessage, final String content, final byte[] binaryContent, final String downloadPath, final Map<String,String> headers) {
                Map<String,Object> result = new HashMap<>();
                result.put("status", statusCode);
                if (statusCode >= 400) {
                    result.put("error", statusMessage);
                }
                result.put("content", content);

                // Binary data needs to be passed as base64 string for now, because Maps are encoded to JSON to be passed to Haxe
                result.put("binaryContent", binaryContent != null ? Base64.encodeToString(binaryContent, Base64.NO_WRAP) : null);

                result.put("headers", headers);

                done.run(result);
            }

        }).execute();

    }

    /** Download file */
    public static void download(final Map<String,Object> params, String targetPath, final Func1<String,Void> done) {

        new HttpRequest(params, targetPath, new HttpRequest.Listener() {

            @Override
            public void onComplete(final int statusCode, final String statusMessage, final String content, final byte[] binaryContent, final String downloadPath, final Map<String,String> headers) {

                if (statusCode >= 400) {
                    Log.e("CERAMIC", statusCode + " / " + statusMessage);
                }

                done.run(downloadPath);
            }

        }).execute();

    }

}

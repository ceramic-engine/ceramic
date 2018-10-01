package ceramic.support;

import java.util.HashMap;
import java.util.Map;

import bind.Support.*;
import ceramic.support.http.HttpRequest;

public class Http {

    public static void sendHttpRequest(final Map<String,Object> params, final Func1<Map<String,Object>,Void> done) {

        new HttpRequest(params, new HttpRequest.Listener() {

            @Override
            public void onComplete(final int statusCode, final String statusMessage, final String content, final Map<String,String> headers) {
                Map<String,Object> result = new HashMap<>();
                result.put("status", statusCode);
                if (statusCode >= 400) {
                    result.put("error", statusMessage);
                }
                result.put("content", content);
                result.put("headers", headers);

                done.run(result);
            }

        }).execute();

    } //sendHttpRequest

} //Http

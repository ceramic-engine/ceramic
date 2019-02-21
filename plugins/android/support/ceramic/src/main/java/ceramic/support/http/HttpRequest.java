package ceramic.support.http;

import android.os.AsyncTask;
import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Created by jeremyfa on 13/10/2016.
 */
public class HttpRequest extends AsyncTask<String, Void, Void> {

    public interface Listener {
        void onComplete(int statusCode, String statusMessage, String content, Map<String,String> headers);
    }

    private final Map<String,Object> mParams;
    private Listener mListener;

    private int mStatusCode;
    private String mStatusMessage;
    private String mContent;
    private Map<String,String> mHeaders;

    public HttpRequest(Map<String,Object> params, Listener listener) {
        mParams = params;
        mListener = listener;
    }

    @Override
    protected Void doInBackground(String... strings) {

        try {
            Map<String,Object> params = mParams;

            URL url = new URL((String) params.get("url"));
            HttpURLConnection connection = null;

            try {
                connection = (HttpURLConnection) url.openConnection();

                // Default user agent
                String userAgent = System.getProperty("http.agent");
                if (userAgent != null) {
                    connection.setRequestProperty("User-Agent", userAgent);
                }

                // Method
                if (params.get("method") != null) {
                    String method = (String) params.get("method");
                    if (method != null) {
                        connection.setRequestMethod(method);
                    } else {
                        connection.setRequestMethod("GET");
                    }
                }

                // Headers
                if (params.get("headers") != null) {
                    Map<String,String> headers = (Map<String,String>) params.get("headers");
                    for (String key : headers.keySet()) {
                        if (headers.get(key) != null) {
                            String val = "" + headers.get(key);
                            connection.setRequestProperty(key, val);
                        }
                    }
                }

                // Timeout
                if (params.get("timeout") != null) {
                    int timeout = (Integer) params.get("timeout");
                    connection.setConnectTimeout(timeout * 1000);
                    connection.setReadTimeout(timeout * 1000);
                }

                // Body
                if (params.get("content") != null) {
                    DataOutputStream os = new DataOutputStream(connection.getOutputStream());
                    os.writeBytes((String) params.get("content"));
                    os.flush();
                    os.close();
                }

                mStatusCode = connection.getResponseCode();
                mStatusMessage = connection.getResponseMessage();
                mHeaders = new HashMap<>();

                BufferedReader br = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
                String line;
                StringBuilder responseOutput = new StringBuilder();
                while ((line = br.readLine()) != null) {
                    responseOutput.append(line);
                    responseOutput.append('\n');
                }
                br.close();

                mContent = responseOutput.toString();

                for (String name : connection.getHeaderFields().keySet()) {
                    if (name != null) mHeaders.put(name, connection.getHeaderField(name));
                }

            } catch (Throwable e) {
                e.printStackTrace();

                mStatusCode = 0;
                mStatusMessage = e.getClass().getSimpleName() + " " + e.getMessage();
                mContent = null;
                mHeaders = new HashMap<>();

            } finally {
                if (connection != null) connection.disconnect();
            }

        } catch (Throwable e) {
            e.printStackTrace();

            mStatusCode = 0;
            mStatusMessage = e.getClass().getSimpleName() + " " + e.getMessage();
            mContent = null;
            mHeaders = new HashMap<>();
        }

        // Provide result
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                if (mListener != null) {
                    mListener.onComplete(mStatusCode, mStatusMessage, mContent, mHeaders);
                    mListener = null;
                }
            }
        });

        return null;
    }
}

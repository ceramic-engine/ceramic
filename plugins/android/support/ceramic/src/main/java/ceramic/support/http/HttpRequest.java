package ceramic.support.http;

import android.content.Context;
import android.os.AsyncTask;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import bind.Support;

/**
 * Created by jeremyfa on 13/10/2016.
 */
public class HttpRequest extends AsyncTask<String, Void, Void> {

    public interface Listener {
        void onComplete(int statusCode, String statusMessage, String content, byte[] binaryContent, String downloadPath, Map<String,String> headers);
    }

    private final Map<String,Object> mParams;
    private Listener mListener;

    private int mStatusCode;
    private String mStatusMessage;
    private String mContent;
    private byte[] mBinaryContent;
    private String mTargetDownloadPath;
    private String mFinalDownloadPath;
    private Map<String,String> mHeaders;

    public HttpRequest(Map<String,Object> params, String downloadPath, Listener listener) {
        mParams = params;
        mFinalDownloadPath = null;
        mTargetDownloadPath = downloadPath;
        mListener = listener;
    }

    @Override
    protected Void doInBackground(String... strings) {

        try {
            Map<String,Object> params = mParams;

            String tmpDownloadPath = null;
            String downloadPath = mTargetDownloadPath;
            File downloadFile = null;
            File tmpDownloadFile = null;
            if (downloadPath != null) {
                // Configure download path
                downloadFile = new File(downloadPath);
                if (!downloadFile.isAbsolute()) {
                    downloadFile = new File(Support.getContext().getFilesDir().getAbsolutePath(), downloadPath);
                    downloadPath = downloadFile.getAbsolutePath();
                }

                // Create target directory if needed
                File downloadDir = downloadFile.getParentFile();
                if (downloadDir.exists()) {
                    if (!downloadDir.isDirectory()) {
                        throw new Error(downloadDir + " is a file. Should be a directory");
                    }
                }
                else {
                    downloadDir.mkdirs();
                }

                // Overwrite any existing tmp download file
                tmpDownloadFile = new File(downloadPath + ".tmpdl");
                if (tmpDownloadFile.exists()) {
                    if (tmpDownloadFile.isDirectory()) {
                        throw new Error("Cannot overwrite " + tmpDownloadFile + " directory.");
                    }
                    tmpDownloadFile.delete();
                }
            }

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

                String contentType = null;
                for (String name : connection.getHeaderFields().keySet()) {
                    if (name != null) {
                        mHeaders.put(name, connection.getHeaderField(name));
                        if (contentType == null && name.toLowerCase().equals("content-type")) {
                            contentType = connection.getHeaderField(name).trim();
                        }
                    }
                }

                if (downloadFile == null) {
                    if (contentType.toLowerCase().startsWith("text/")) {
                        // Text content
                        BufferedReader br = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
                        String line;
                        StringBuilder responseOutput = new StringBuilder();
                        while ((line = br.readLine()) != null) {
                            responseOutput.append(line);
                            responseOutput.append('\n');
                        }
                        br.close();

                        mContent = responseOutput.toString();
                        mBinaryContent = null;
                    }
                    else {
                        // Binary content
                        ByteArrayOutputStream buffer = new ByteArrayOutputStream();

                        int nRead;
                        byte[] data = new byte[16384];
                        InputStream is = connection.getInputStream();
                        while ((nRead = is.read(data, 0, data.length)) != -1) {
                            buffer.write(data, 0, nRead);
                        }
                        is.close();

                        mContent = null;
                        mBinaryContent = buffer.toByteArray();
                    }
                }
                else if (mStatusCode >= 200 && mStatusCode < 300) {
                    // A download path was provided, store result in tmp file, works with binary data as well
                    FileOutputStream fileOutput = new FileOutputStream(tmpDownloadFile);
                    InputStream inputStream = connection.getInputStream();

                    byte[] buffer = new byte[1024];
                    int bufferLength = 0;

                    while ( (bufferLength = inputStream.read(buffer)) > 0 ) {
                        fileOutput.write(buffer, 0, bufferLength);
                    }
                    fileOutput.close();

                    // Copy to final path
                    if (downloadFile.exists()) {
                        if (downloadFile.isDirectory()) {
                            throw new Error("Cannot overwrite " + downloadFile + " directory.");
                        }
                        downloadFile.delete();
                    }
                    tmpDownloadFile.renameTo(downloadFile);
                    mFinalDownloadPath = downloadFile.getAbsolutePath();
                }

            } catch (Throwable e) {
                Log.e("CERAMIC", "Http error: " + e.getMessage());
                e.printStackTrace();

                mStatusCode = 0;
                mStatusMessage = e.getClass().getSimpleName() + " " + e.getMessage();
                mContent = null;
                mBinaryContent = null;
                mHeaders = new HashMap<>();

            } finally {
                if (connection != null) connection.disconnect();
            }

        } catch (Throwable e) {
            e.printStackTrace();

            mStatusCode = 0;
            mStatusMessage = e.getClass().getSimpleName() + " " + e.getMessage();
            mContent = null;
            mBinaryContent = null;
            mHeaders = new HashMap<>();
        }

        // Provide result
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                if (mListener != null) {
                    mListener.onComplete(mStatusCode, mStatusMessage, mContent, mBinaryContent, mFinalDownloadPath, mHeaders);
                    mListener = null;
                }
            }
        });

        return null;
    }
}

package backend;

import ceramic.Path;
import ceramic.Shortcuts.*;

#if (cs && unity)
import unityengine.networking.DownloadHandler;
#end

#if (cpp || cs || sys || nodejs || hxnodejs || node)
import sys.FileSystem;
#end

/**
 * Platform-specific HTTP implementation providing cross-platform HTTP request functionality.
 *
 * This class implements the low-level HTTP backend for the Ceramic HTTP plugin, providing
 * native HTTP request capabilities across all supported platforms including:
 *
 * Supported Platforms:
 * - Node.js (nodejs/hxnodejs/node): Uses Node.js http/https modules
 * - Android: Uses Android native HTTP implementation
 * - iOS: Uses iOS native HTTP implementation
 * - Web/JS: Uses XMLHttpRequest with ArrayBuffer responses
 * - Unity C#: Uses UnityWebRequest with coroutine-based async handling
 * - Tink HTTP: Uses tink_http library for additional platform support
 * - AkifoxAsyncHttp: Alternative HTTP library support
 *
 * Features:
 * - Automatic redirect handling (up to 8 redirects)
 * - Timeout support with proper cleanup
 * - Binary and text response handling based on MIME types
 * - Header processing and normalization
 * - File download capabilities with progress tracking
 * - Cross-platform error handling and reporting
 *
 * The implementation automatically detects the target platform and uses the most
 * appropriate HTTP mechanism available. All platform-specific code is contained
 * within conditional compilation blocks.
 *
 * Note: This class should not be used directly by application code. Use the
 * high-level ceramic.Http class instead.
 */
#if (cs && unity)
@:classCode('
System.Collections.IEnumerator unityRunWebRequest(int id, UnityEngine.Networking.UnityWebRequest request) {
    yield return request.SendWebRequest();
    unityHandleWebRequestResponse(id, request.downloadHandler);
}
')
#end
class Http implements spec.Http {

    #if (cs && unity)
    /** Unity-specific: Counter for generating unique request IDs */
    public var nextRequestId:Int = 1;

    /** Unity-specific: Map of request IDs to their completion callbacks */
    public var requestCallbacks:Map<Int, DownloadHandler->Void> = new Map();

    /**
     * Unity-specific callback handler for completed web requests.
     *
     * This method is called from the Unity coroutine when a web request completes.
     * It retrieves and executes the appropriate callback for the request.
     *
     * @param requestId The unique ID of the completed request
     * @param downloadHandler The Unity download handler containing the response data
     */
    @:keep function unityHandleWebRequestResponse(requestId:Int, downloadHandler:DownloadHandler):Void {

        var callback:DownloadHandler->Void = requestCallbacks.get(requestId);
        if (callback != null) {
            requestCallbacks.remove(requestId);
            callback(downloadHandler);
            callback = null;
        }

    }
    #end

    /** Creates a new HTTP backend instance */
    public function new() {}

    /**
     * Performs an HTTP request using the appropriate platform-specific implementation.
     *
     * This method dispatches to the correct platform implementation and ensures
     * that the response callback is executed on the main thread for thread safety.
     * It handles the complete request lifecycle including timeouts, redirects,
     * and proper resource cleanup.
     *
     * The method automatically:
     * - Detects and handles different content types (text vs binary)
     * - Follows HTTP redirects (up to 8 levels deep)
     * - Applies timeouts and handles timeout cleanup
     * - Processes response headers and status codes
     * - Ensures thread-safe callback execution
     *
     * @param options The HTTP request configuration
     * @param requestDone Callback function that receives the HTTP response
     */
    public function request(options:HttpRequestOptions, requestDone:HttpResponse->Void):Void {

        var done:HttpResponse->Void = null;
        done = (response:HttpResponse) -> {
            ceramic.App.app.onceUpdate(null, _ -> {
                requestDone(response);
                requestDone = null;
                done = null;
            });
        };

        #if ceramic_http_custom

        // This allows a different plugin to provide an alternative implementation
        // of HTTP that isn't available directly from the http plugin.
        backend.http.HttpCustom.request(options, done);

        #elseif (nodejs || hxnodejs || node)
        backend.http.HttpNodejs.request(options, done);
        #elseif android
        backend.http.HttpAndroid.request(options, done);
        #elseif ios
        backend.http.HttpIos.request(options, done);
        #elseif js
        backend.http.HttpWeb.request(options, done);
        #elseif (cs && unity)
        backend.http.HttpUnity.request(options, done, this);
        #elseif ceramic_http_tink
        backend.http.HttpTink.request(options, done);
        #elseif akifox_asynchttp
        backend.http.HttpAkifox.request(options, done);
        #else
        // Not implemented
        done({
            status: 404,
            content: null,
            binaryContent: null,
            headers: new Map(),
            error: 'Not implemented'
        });
        #end

    }

    /**
     * Downloads a file from the specified URL to a local file path.
     *
     * This method provides cross-platform file download functionality with automatic
     * path resolution and temporary file handling for safe downloads. The implementation
     * varies by platform to use the most efficient download mechanism available.
     *
     * Features:
     * - Automatic path resolution (relative paths are resolved against storage directory)
     * - Safe download using temporary files (prevents corruption on failure)
     * - Platform-optimized download methods (curl on Unix, native APIs on mobile)
     * - Automatic directory creation if needed
     * - Progress tracking and error handling
     *
     * Platform implementations:
     * - iOS/Android: Uses native download APIs with progress callbacks
     * - Mac/Linux: Uses system curl command for reliable downloads
     * - Windows: Uses curl via PowerShell
     * - Unity: Uses UnityWebRequest with file download handler
     * - Node.js: Uses http/https modules with file streams
     *
     * The method ensures atomic downloads by first downloading to a temporary file
     * (.tmpdl extension) and then moving it to the final location upon success.
     *
     * @param url The URL of the file to download
     * @param targetPath The local file path where the file should be saved (can be relative)
     * @param done Callback function that receives the final file path on success, or null on failure
     */
    public function download(url:String, targetPath:String, done:String->Void):Void {

        if (!Path.isAbsolute(targetPath)) {
            var basePath = app.backend.info.storageDirectory();
            if (basePath == null) {
                log.warning('Cannot download $url at path $targetPath because there is no storage directory');
                done(null);
                return;
            }
            targetPath = Path.join([basePath, targetPath]);
        }

        var tmpTargetPath = targetPath + '.tmpdl';

        #if ios

        backend.http.HttpIos.download(url, targetPath, done);

        #elseif android

        backend.http.HttpAndroid.download(url, targetPath, done);

        #elseif (nodejs || hxnodejs || node)

        // Ensure we can write the file at the desired location
        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.isDirectory(tmpTargetPath)) {
                log.error('Cannot overwrite directory named $tmpTargetPath');
                done(null);
                return;
            }
            FileSystem.deleteFile(tmpTargetPath);
        }
        var dir = Path.directory(tmpTargetPath);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
        else if (!FileSystem.isDirectory(dir)) {
            log.error('Target directory $dir should be a directory, but it is a file');
            done(null);
            return;
        }

        backend.http.HttpNodejs.download(url, tmpTargetPath, targetPath, done);

        #elseif (cs && unity)

        // Ensure we can write the file at the desired location
        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.isDirectory(tmpTargetPath)) {
                log.error('Cannot overwrite directory named $tmpTargetPath');
                done(null);
                return;
            }
            FileSystem.deleteFile(tmpTargetPath);
        }
        var dir = Path.directory(tmpTargetPath);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
        else if (!FileSystem.isDirectory(dir)) {
            log.error('Target directory $dir should be a directory, but it is a file');
            done(null);
            return;
        }

        backend.http.HttpUnity.download(url, tmpTargetPath, targetPath, done, this);

        #elseif (cpp || sys)

        // Ensure we can write the file at the desired location
        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.isDirectory(tmpTargetPath)) {
                log.error('Cannot overwrite directory named $tmpTargetPath');
                done(null);
                return;
            }
            FileSystem.deleteFile(tmpTargetPath);
        }
        var dir = Path.directory(tmpTargetPath);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
        else if (!FileSystem.isDirectory(dir)) {
            log.error('Target directory $dir should be a directory, but it is a file');
            done(null);
            return;
        }

        backend.http.HttpNative.download(url, tmpTargetPath, targetPath, done);

        #else

        // Too bad
        log.error('Cannot download $url at path $targetPath because download is not supported on this target');
        done(null);

        #end

    }

}

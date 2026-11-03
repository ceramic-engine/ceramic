package ceramic;

import ceramic.Shortcuts.*;
import haxe.io.Bytes;

using StringTools;

/**
 * Files of a browser page, which has no file system: downloads and files
 * picked by the user.
 *
 * A page can neither choose where a file is saved nor read a file by its
 * path. Ceramic gives such files pseudo paths that the usual `Files`
 * functions understand, so code written for a file system keeps working:
 *
 * - **Download paths** (`download:<name>`): `Dialogs.chooseNewPath` returns
 *   one in a browser (no dialog: the browser decides where downloads go).
 *   `Files.saveContent` and `Files.saveBytes` on such a path start a browser
 *   download of the data, named `<name>`. Nothing can be read back from it.
 * - **Picked paths** (`picked:<n>/<name>`, `picked:<n>/<folder>/...`):
 *   `Dialogs.choosePaths` returns them in a browser for the files (or the
 *   folders) the user chose in the browser's file chooser. Their content is
 *   read into memory before the paths are returned, so `Files.getContent`,
 *   `Files.getBytes`, `Files.getSize`, `Files.exists`, `Files.isDirectory`
 *   and `Files.getFlatDirectory` work on them synchronously. `forget`
 *   releases that memory.
 *
 * The bookkeeping is plain Haxe and works on every target (tests use it with
 * `downloadHandler`); only the download itself needs a browser.
 */
class BrowserFiles {

    /** Prefix of the download paths. */
    public static inline final DOWNLOAD_PREFIX = 'download:';

    /** Prefix of the picked paths. */
    public static inline final PICKED_PREFIX = 'picked:';

    /**
     * When set, receives the downloads instead of the browser (tests,
     * embedders, and every target that is not a browser).
     */
    public static var downloadHandler:Null<(name:String, bytes:Bytes, mimeType:String)->Void> = null;

    static var picked:Map<String, Bytes> = new Map();

    static var pickedDirectories:Map<String, Bool> = new Map();

    static var nextPick:Int = 1;

    /** Whether `path` is a download or a picked path. */
    public static function isBrowserPath(path:Null<String>):Bool {
        return path != null && (path.startsWith(DOWNLOAD_PREFIX) || path.startsWith(PICKED_PREFIX));
    }

    /** Whether `path` is a download path. */
    public static function isDownloadPath(path:Null<String>):Bool {
        return path != null && path.startsWith(DOWNLOAD_PREFIX);
    }

    /** Whether `path` is a picked path. */
    public static function isPickedPath(path:Null<String>):Bool {
        return path != null && path.startsWith(PICKED_PREFIX);
    }

    /**
     * The download path of a file named `name`. Folders and characters that
     * file names cannot hold are dropped; an empty name gives `download`.
     */
    public static function downloadPath(name:Null<String>):String {
        return DOWNLOAD_PREFIX + safeName(name);
    }

    /** The file name of a download path. */
    public static function downloadName(path:String):String {
        return safeName(path.startsWith(DOWNLOAD_PREFIX) ? path.substr(DOWNLOAD_PREFIX.length) : path);
    }

    static function safeName(name:Null<String>):String {
        if (name == null) return 'download';
        name = name.replace('\\', '/');
        final slash = name.lastIndexOf('/');
        if (slash >= 0) name = name.substr(slash + 1);
        final buf = new StringBuf();
        for (i in 0...name.length) {
            final c = name.fastCodeAt(i);
            if (c < 32 || c == ':'.code || c == '*'.code || c == '?'.code || c == '"'.code || c == '<'.code || c == '>'.code || c == '|'.code) continue;
            buf.addChar(c);
        }
        final result = buf.toString().trim();
        return result.length > 0 && result != '.' && result != '..' ? result : 'download';
    }

    /**
     * Saves `bytes` as a download named `name`: a browser download (a Blob
     * behind a temporary link with a `download` attribute), or
     * `downloadHandler` when set. Returns false when neither is available.
     * Browsers may ask the user before a page downloads several files in a
     * row.
     */
    public static function download(name:String, bytes:Bytes, ?mimeType:String):Bool {
        name = safeName(name);
        if (mimeType == null) mimeType = mimeTypeOf(name);
        if (downloadHandler != null) {
            downloadHandler(name, bytes, mimeType);
            return true;
        }
        #if web
        final document = js.Browser.document;
        if (document == null || document.body == null) {
            log.warning('download() needs a document');
            return false;
        }
        final data = new js.lib.Uint8Array(bytes.getData(), 0, bytes.length);
        final blob = new js.html.Blob([data], {type: mimeType});
        final url = js.html.URL.createObjectURL(blob);
        final link = document.createAnchorElement();
        link.href = url;
        link.download = name;
        link.style.display = 'none';
        document.body.appendChild(link);
        link.click();
        link.remove();
        // The browser reads the Blob asynchronously: keep the URL alive a while
        js.Browser.window.setTimeout(() -> js.html.URL.revokeObjectURL(url), 60000);
        return true;
        #else
        log.warning('download() is only available in a browser (or with BrowserFiles.downloadHandler)');
        return false;
        #end
    }

    /** A MIME type for common text extensions, else `application/octet-stream`. */
    public static function mimeTypeOf(name:String):String {
        final dot = name.lastIndexOf('.');
        final ext = dot >= 0 ? name.substr(dot + 1).toLowerCase() : '';
        return switch ext {
            case 'csv': 'text/csv';
            case 'txt' | 'log' | 'md': 'text/plain';
            case 'json': 'application/json';
            case 'html' | 'htm': 'text/html';
            case 'svg': 'image/svg+xml';
            case 'png': 'image/png';
            case 'jpg' | 'jpeg': 'image/jpeg';
            case _: 'application/octet-stream';
        }
    }

    /**
     * Starts a new pick: the prefix (`picked:<n>/`) under which the files
     * the user chose this time are added with `addPicked`.
     */
    public static function newPick():String {
        return PICKED_PREFIX + (nextPick++) + '/';
    }

    /**
     * Adds a picked file: `relativePath` is its name, or its path inside the
     * chosen folder (`folder/sub/file.txt`). Returns its picked path. The
     * folders on the way become picked folders.
     */
    public static function addPicked(pick:String, relativePath:String, bytes:Bytes):String {
        relativePath = relativePath.replace('\\', '/');
        while (relativePath.startsWith('/')) relativePath = relativePath.substr(1);
        final path = pick + relativePath;
        picked.set(path, bytes);
        var slash = relativePath.indexOf('/');
        while (slash >= 0) {
            pickedDirectories.set(pick + relativePath.substr(0, slash), true);
            slash = relativePath.indexOf('/', slash + 1);
        }
        return path;
    }

    /** The content of a picked file, or null. */
    public static function getPicked(path:String):Null<Bytes> {
        return picked.get(normalize(path));
    }

    /** Whether `path` is a picked folder. */
    public static function isPickedDirectory(path:String):Bool {
        return pickedDirectories.exists(normalize(path));
    }

    /** Whether `path` is a picked file or folder. */
    public static function pickedExists(path:String):Bool {
        path = normalize(path);
        return picked.exists(path) || pickedDirectories.exists(path);
    }

    /** The picked files inside a picked folder, at any depth, sorted. */
    public static function pickedFilesIn(directory:String):Array<String> {
        final prefix = normalize(directory) + '/';
        final result = [for (path in picked.keys()) if (path.startsWith(prefix)) path];
        result.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return result;
    }

    /** Releases a picked file, or every file of a picked folder or pick. */
    public static function forget(path:String):Void {
        path = normalize(path);
        picked.remove(path);
        pickedDirectories.remove(path);
        final prefix = path.endsWith('/') ? path : path + '/';
        for (key in [for (k in picked.keys()) k]) if (key.startsWith(prefix)) picked.remove(key);
        for (key in [for (k in pickedDirectories.keys()) k]) if (key.startsWith(prefix)) pickedDirectories.remove(key);
    }

    static function normalize(path:String):String {
        return path.endsWith('/') ? path.substr(0, path.length - 1) : path;
    }

}

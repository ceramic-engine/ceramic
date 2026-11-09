// Ported from vscode src/vs/base/common/resources.ts (`dirname`,
// `basename`, `basenameOrAuthority`) and src/vs/base/common/labels.ts
// (`normalizeDriveLetter`)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * The functions of resources.ts (the default `extUri`, posix paths) and
 * labels.ts that Cityscape uses.
 */
class Resources {

    /**
     * Return a URI representing the directory of a URI path.
     */
    public static function dirname(resource:Uri):Uri {
        if (resource.path.length == 0) {
            return resource;
        }
        var dirname:String;
        if (resource.scheme == 'file') {
            dirname = Uri.file(Path.dirname(resource.fsPath)).path;
        }
        else {
            dirname = Path.dirname(resource.path);
            if (resource.authority.length > 0 && dirname.length > 0 && StringTools.fastCodeAt(dirname, 0) != '/'.code) {
                // If a URI contains an authority component, then the path
                // component must either be empty or begin with a slash
                dirname = '/';
            }
        }
        return resource.with({path: dirname});
    }

    /**
     * Returns the last segment of the path of a URI.
     */
    public static function basename(resource:Uri):String {
        return Path.basename(resource.path);
    }

    /**
     * The basename of the path of a URI, or its authority when the path is
     * empty or `/`.
     */
    public static function basenameOrAuthority(resource:Uri):String {
        final name = basename(resource);
        return name.length > 0 ? name : resource.authority;
    }

    /**
     * labels.ts `normalizeDriveLetter`: an upper case drive letter on
     * Windows (`c:\x` is `C:\x`), the path as it is elsewhere.
     */
    public static function normalizeDriveLetter(path:String, ?isWindowsOS:Bool):String {
        final windows = isWindowsOS != null ? isWindowsOS : Platform.isWindows;
        if (windows && path.length >= 2 && StringTools.fastCodeAt(path, 1) == ':'.code) {
            final c = StringTools.fastCodeAt(path, 0);
            if ((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code)) {
                return path.charAt(0).toUpperCase() + path.substr(1);
            }
        }
        return path;
    }

}

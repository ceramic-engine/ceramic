/*
 * Copyright (C)2005-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
//package haxe.io;
package ceramic;

// Same as haxe.io.Path except that it doesn't depend on EReg

/**
 * Cross-platform path manipulation utilities optimized for Ceramic.
 * 
 * This class provides a convenient way of working with file and directory paths
 * across different platforms. It is a modified version of haxe.io.Path that doesn't
 * depend on regular expressions (EReg), making it more efficient for frequent path
 * operations in game development.
 * 
 * Supports common path formats:
 * - Unix/Mac/Linux: `directory1/directory2/filename.extension`
 * - Windows: `directory1\directory2\filename.extension`
 * - Windows absolute: `C:\directory\file.ext`
 * - Network paths: `\\server\share\file.ext`
 * 
 * Example usage:
 * ```haxe
 * // Parse a path
 * var path = new Path("assets/images/player.png");
 * trace(path.dir);  // "assets/images"
 * trace(path.file); // "player"
 * trace(path.ext);  // "png"
 * 
 * // Manipulate paths
 * var newPath = Path.withExtension("image.jpg", "png"); // "image.png"
 * var joined = Path.join(["assets", "sounds", "music.ogg"]); // "assets/sounds/music.ogg"
 * var normalized = Path.normalize("/usr/local/../lib"); // "/usr/lib"
 * 
 * // Check path properties
 * if (Path.isAbsolute("/home/user")) {
 *     trace("Absolute path");
 * }
 * ```
 * 
 * @see ceramic.Files For file system operations
 * @see ceramic.Assets For asset path management
 */
class Path {

    /**
     * The directory portion of the path.
     * 
     * This is the leading part of the path that is not part of the file name
     * and the extension. Does not include a trailing `/` or `\` separator.
     * 
     * Examples:
     * - Path "dir/file.txt" -> dir = "dir"
     * - Path "file.txt" -> dir = null
     * - Path "/home/user/file.txt" -> dir = "/home/user"
     * - Path "C:\\Windows\\file.txt" -> dir = "C:\\Windows"
     */
    public var dir : String;

    /**
     * The file name without extension.
     * 
     * This is the part of the path between the directory and the extension.
     * For files that start with a dot (like .htaccess) or paths ending with
     * a separator, the value is an empty string "".
     * 
     * Examples:
     * - Path "dir/file.txt" -> file = "file"
     * - Path ".htaccess" -> file = ""
     * - Path "/dir/" -> file = ""
     * - Path "document.tar.gz" -> file = "document.tar"
     */
    public var file : String;

    /**
     * The file extension without the leading dot.
     * 
     * The extension is the part after the last dot in the filename.
     * The separating dot is not included in the extension value.
     * 
     * Examples:
     * - Path "file.txt" -> ext = "txt"
     * - Path "archive.tar.gz" -> ext = "gz"
     * - Path "file" -> ext = null
     * - Path ".htaccess" -> ext = "htaccess"
     */
    public var ext : String;

    /**
     * Indicates the type of directory separator used in the original path.
     * 
     * True if the last directory separator found was a backslash (`\\`),
     * false if it was a forward slash (`/`) or if no separator was found.
     * This helps preserve the original path style when converting back to string.
     */
    public var backslash : Bool;

    /**
     * Creates a new Path instance by parsing the given path string.
     * 
     * The path is split into its components (directory, filename, extension)
     * which can be accessed through the corresponding properties.
     * Handles both forward slash and backslash separators.
     * 
     * Special cases:
     * - "." and ".." are treated as directories with empty filenames
     * - Paths ending with separators have empty filenames
     * 
     * @param path The path string to parse
     */
    public function new( path : String ) {
        switch (path) {
            case "." | "..":
                dir = path;
                file = "";
                return;
        }
        var c1 = path.lastIndexOf("/");
        var c2 = path.lastIndexOf("\\");
        if( c1 < c2 ) {
            dir = path.substr(0,c2);
            path = path.substr(c2+1);
            backslash = true;
        } else if( c2 < c1 ) {
            dir = path.substr(0,c1);
            path = path.substr(c1+1);
        } else
            dir = null;
        var cp = path.lastIndexOf(".");
        if( cp != -1 ) {
            ext = path.substr(cp+1);
            file = path.substr(0,cp);
        } else {
            ext = null;
            file = path;
        }
    }

    /**
     * Reconstructs the path string from its components.
     * 
     * The directory separator used depends on the `backslash` property:
     * - If true, uses backslash (`\\`) as separator
     * - If false, uses forward slash (`/`) as separator
     * 
     * Null components are treated as empty strings.
     * 
     * @return The reconstructed path string
     */
    public function toString() : String {
        return (if( dir == null ) "" else dir + if( backslash ) "\\" else "/") + file + (if( ext == null ) "" else "." + ext);
    }

    /**
     * Removes the file extension from a path string.
     * 
     * Example:
     * ```haxe
     * Path.withoutExtension("image.png"); // "image"
     * Path.withoutExtension("path/to/file.txt"); // "path/to/file"
     * ```
     * 
     * @param path The path to process
     * @return The path without its extension
     */
    public static function withoutExtension( path : String ) : String {
        var s = new Path(path);
        s.ext = null;
        return s.toString();
    }

    /**
     * Extracts only the filename and extension from a path.
     * 
     * Example:
     * ```haxe
     * Path.withoutDirectory("/home/user/file.txt"); // "file.txt"
     * Path.withoutDirectory("assets/image.png"); // "image.png"
     * ```
     * 
     * @param path The path to process
     * @return The filename with extension, without directory
     */
    public static function withoutDirectory( path ) : String {
        var s = new Path(path);
        s.dir = null;
        return s.toString();
    }

    /**
     * Extracts the directory portion of a path.
     * 
     * Example:
     * ```haxe
     * Path.directory("/home/user/file.txt"); // "/home/user"
     * Path.directory("file.txt"); // ""
     * ```
     * 
     * @param path The path to process
     * @return The directory portion, or empty string if none
     */
    public static function directory( path ) : String {
        var s = new Path(path);
        if( s.dir == null )
            return "";
        return s.dir;
    }

    /**
     * Extracts the file extension from a path.
     * 
     * Example:
     * ```haxe
     * Path.extension("image.png"); // "png"
     * Path.extension("archive.tar.gz"); // "gz"
     * Path.extension("README"); // ""
     * ```
     * 
     * @param path The path to process
     * @return The extension without dot, or empty string if none
     */
    public static function extension( path ) : String {
        var s = new Path(path);
        if( s.ext == null )
            return "";
        return s.ext;
    }

    /**
     * Changes or adds a file extension to a path.
     * 
     * Example:
     * ```haxe
     * Path.withExtension("image.jpg", "png"); // "image.png"
     * Path.withExtension("document", "pdf"); // "document.pdf"
     * ```
     * 
     * @param path The path to modify
     * @param ext The new extension (without dot)
     * @return The path with the new extension
     */
    public static function withExtension( path, ext ) : String {
        var s = new Path(path);
        s.ext = ext;
        return s.toString();
    }

    /**
     * Joins multiple path segments into a single path.
     * 
     * Automatically adds separators between segments and normalizes
     * the result. Empty segments are filtered out.
     * 
     * Example:
     * ```haxe
     * Path.join(["assets", "images", "player.png"]); // "assets/images/player.png"
     * Path.join(["/home", "user", "docs"]); // "/home/user/docs"
     * ```
     * 
     * @param paths Array of path segments to join
     * @return The joined and normalized path
     */
    public static function join(paths:Array<String>) : String {
        var paths = paths.filter(function(s) return s != null && s != "");
        if (paths.length == 0) {
            return "";
        }
        var path = paths[0];
        for (i in 1...paths.length) {
            path = addTrailingSlash(path);
            path += paths[i];
        }
        return normalize(path);
    }

    /**
     * Normalizes a path by resolving relative segments and cleaning separators.
     * 
     * Operations performed:
     * - Converts all backslashes to forward slashes
     * - Resolves `.` (current directory) and `..` (parent directory) segments
     * - Removes duplicate slashes (except after colons for Windows drives)
     * - Preserves absolute path indicators
     * 
     * Example:
     * ```haxe
     * Path.normalize("/usr/local/../lib"); // "/usr/lib"
     * Path.normalize("./assets//images/."); // "assets/images"
     * Path.normalize("C:\\Users\\..\\Windows"); // "C:/Windows"
     * ```
     * 
     * @param path The path to normalize
     * @return The normalized path
     */
    public static function normalize(path : String) : String {
        var slash = "/";
        path = path.split("\\").join(slash);
        if (path == slash) return slash;

        var target = [];

        for( token in path.split(slash) ) {
            if(token == '..' && target.length > 0 && target[target.length-1] != "..") {
                target.pop();
            } else if(token != '.') {
                target.push(token);
            }
        }

        var tmp = target.join(slash);
        var doubleSlashIndex = -1;
        while ((doubleSlashIndex = tmp.indexOf('//')) != -1) {
            tmp = tmp.substring(0, doubleSlashIndex) + tmp.substring(doubleSlashIndex + 1);
        }
        // Original code. BTW, result var is not used afterwards in method??
        //var regex = ~/([^:])\/+/g;
        //var result = regex.replace(tmp, "$1" +slash);
        var acc = new StringBuf();
        var colon = false;
        var slashes = false;
        for (i in 0...tmp.length) {
            switch (StringTools.fastCodeAt(tmp, i)) {
                case ":".code:
                    acc.add(":");
                    colon = true;
                case "/".code if (!colon):
                    slashes = true;
                case i:
                    colon = false;
                    if (slashes) {
                        acc.add("/");
                        slashes = false;
                    }
                    acc.addChar(i);
            }
        }
        return acc.toString();
    }

    /**
     * Ensures a path ends with a directory separator.
     * 
     * The type of separator added matches the existing separators in the path:
     * - If the last separator is a backslash, adds a backslash
     * - Otherwise, adds a forward slash
     * - Empty string becomes "/"
     * 
     * Example:
     * ```haxe
     * Path.addTrailingSlash("dir"); // "dir/"
     * Path.addTrailingSlash("C:\\Windows"); // "C:\\Windows\\"
     * Path.addTrailingSlash("dir/"); // "dir/" (unchanged)
     * ```
     * 
     * @param path The path to process
     * @return The path with a trailing separator
     */
    public static function addTrailingSlash( path : String ) : String {
        if (path.length == 0)
            return "/";
        var c1 = path.lastIndexOf("/");
        var c2 = path.lastIndexOf("\\");
        return if ( c1 < c2 ) {
            if (c2 != path.length - 1) path + "\\";
            else path;
        } else {
            if (c1 != path.length - 1) path + "/";
            else path;
        }
    }

    /**
     * Removes all trailing directory separators from a path.
     * 
     * Strips any combination of trailing forward slashes and backslashes.
     * 
     * Example:
     * ```haxe
     * Path.removeTrailingSlashes("dir/"); // "dir"
     * Path.removeTrailingSlashes("C:\\Windows\\\\"); // "C:\\Windows"
     * Path.removeTrailingSlashes("file.txt"); // "file.txt" (unchanged)
     * ```
     * 
     * @param path The path to process
     * @return The path without trailing separators
     */
    @:require(haxe_ver >= 3.1)
    public static function removeTrailingSlashes ( path : String ) : String {
        while (true) {
            switch(path.charCodeAt(path.length - 1)) {
                case '/'.code | '\\'.code: path = path.substr(0, -1);
                case _: break;
            }
        }
        return path;
    }

    /**
     * Determines if a path is absolute or relative.
     * 
     * A path is considered absolute if it:
     * - Starts with `/` (Unix/Mac/Linux)
     * - Has a drive letter like `C:` (Windows)
     * - Starts with `\\\\` (Windows network path)
     * 
     * Example:
     * ```haxe
     * Path.isAbsolute("/home/user"); // true
     * Path.isAbsolute("C:\\Windows"); // true 
     * Path.isAbsolute("\\\\server\\share"); // true
     * Path.isAbsolute("relative/path"); // false
     * Path.isAbsolute("./file.txt"); // false
     * ```
     * 
     * @param path The path to check
     * @return True if the path is absolute, false if relative
     */
    public static function isAbsolute ( path : String ) : Bool {
        if (StringTools.startsWith(path, '/')) return true;
        if (path.charAt(1) == ':') return true;
        if (StringTools.startsWith(path, '\\\\')) return true;
        return false;
    }

}
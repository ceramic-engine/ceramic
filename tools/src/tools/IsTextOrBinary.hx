package tools;

import haxe.io.Bytes;
import haxe.io.Path;

// Mostly a port of: https://github.com/bevry/istextorbinary

enum abstract IsTextOrBinaryEncoding(Int) {

    var UNKNOWN = 0;

    var UTF8 = 1;

    var BINARY = 2;

}

class IsTextOrBinary {

    // Common text extensions - you may want to expand this list
    private static final textExtensions = [
        "txt", "md", "json", "xml", "html", "css", "js", "hx", "csv", "strings", "m", "h", "hpp", "cpp", "c", "xcworkspacedata", "pbxproj", "pch", "plist", "yml", "yaml", "iml"
    ];

    // Common binary extensions - you may want to expand this list
    private static final binaryExtensions = [
        "png", "jpg", "jpeg", "gif", "pdf", "exe", "dll", "zip", "tar", "gz", "a"
    ];

    /**
        Determines if a file is text or binary based on filename extension and/or content analysis.
        @param filename The filename to check (optional)
        @param bytes The file content as Bytes (optional)
        @return true for text, false for binary (or unknown)
    **/
    public static function isText(filename:Null<String>, bytes:Null<Bytes>):Bool {
        // Check extensions if filename is provided
        if (filename != null) {
            var extension = Path.extension(filename).toLowerCase();
            if (textExtensions.indexOf(extension) != -1) return true;
            if (binaryExtensions.indexOf(extension) != -1) return false;
        }

        // If we have bytes but no conclusive extension check, analyze the content
        if (bytes != null) {
            return getEncoding(bytes) == UTF8;
        }

        return false;
    }

    /**
        Determines if a file is binary.
        @param filename The filename to check (optional)
        @param bytes The file content as Bytes (optional)
        @return true for binary, false for text (or unknown)
    **/
    public static function isBinary(filename:Null<String>, bytes:Null<Bytes>):Bool {
        // Check extensions if filename is provided
        if (filename != null) {
            var extension = Path.extension(filename).toLowerCase();
            if (textExtensions.indexOf(extension) != -1) return false;
            if (binaryExtensions.indexOf(extension) != -1) return true;
        }

        // If we have bytes but no conclusive extension check, analyze the content
        if (bytes != null) {
            return getEncoding(bytes) == BINARY;
        }

        return false;
    }

    /**
        Analyzes bytes to determine if they represent UTF-8 text or binary content.
        @param bytes The content to analyze
        @param chunkLength Optional length of chunks to analyze (default 24)
        @param chunkBegin Optional starting position for analysis
        @return UTF8 for text content, BINARY for binary content, null if no bytes provided
    **/
    public static function getEncoding(bytes:Null<Bytes>, ?chunkLength:Int = 24, ?chunkBegin:Int = 0):IsTextOrBinaryEncoding {
        if (bytes == null) return UNKNOWN;

        // Check three regions: start, middle, and end
        if (chunkBegin == 0) {
            // Check start
            var encoding = analyzeChunk(bytes, 0, chunkLength);
            if (encoding == BINARY) return BINARY;

            // Check middle
            var middleStart = Std.int(Math.max(0, Math.floor(bytes.length / 2) - chunkLength));
            encoding = analyzeChunk(bytes, middleStart, chunkLength);
            if (encoding == BINARY) return BINARY;

            // Check end
            var endStart = Std.int(Math.max(0, bytes.length - chunkLength));
            encoding = analyzeChunk(bytes, endStart, chunkLength);
            return encoding;
        }

        return analyzeChunk(bytes, chunkBegin, chunkLength);

    }

    private static function analyzeChunk(bytes:Bytes, start:Int, length:Int):IsTextOrBinaryEncoding {
        var end = Std.int(Math.min(bytes.length, start + length));

        var i = start;
        while (i < end) {
            var byte = bytes.get(i);

            // Check for control characters or UTF-8 replacement character
            if (byte <= 8 || byte == 0xEF) {
                return BINARY;
            }

            // Basic UTF-8 validity check
            if ((byte & 0x80) != 0) { // If it's a multi-byte character
                if ((byte & 0xE0) == 0xC0) { // 2-byte sequence
                    if (i + 1 >= end || (bytes.get(i + 1) & 0xC0) != 0x80) {
                        return BINARY;
                    }
                    i += 1;
                } else if ((byte & 0xF0) == 0xE0) { // 3-byte sequence
                    if (i + 2 >= end ||
                        (bytes.get(i + 1) & 0xC0) != 0x80 ||
                        (bytes.get(i + 2) & 0xC0) != 0x80) {
                        return BINARY;
                    }
                    i += 2;
                } else if ((byte & 0xF8) == 0xF0) { // 4-byte sequence
                    if (i + 3 >= end ||
                        (bytes.get(i + 1) & 0xC0) != 0x80 ||
                        (bytes.get(i + 2) & 0xC0) != 0x80 ||
                        (bytes.get(i + 3) & 0xC0) != 0x80) {
                        return BINARY;
                    }
                    i += 3;
                } else {
                    return BINARY;
                }
            }

            i++;
        }

        return UTF8;

    }

}
// Ported from gpui-pre 0.3.10: src/elements/img.rs (ImageCacheError)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An error that can occur when interacting with the image cache.
 */
@:using(glaze.ImageCacheError.ImageCacheErrorTools)
enum ImageCacheError {

    /** Some other kind of error occurred */
    Other(message:String);

    /** An error that occurred while reading the image from disk. */
    Io(message:String);

    /** Unexpected http status (Rust `BadStatus`) */
    BadStatus(uri:String, status:Int, body:String);

    /** An error that occurred while processing an asset. */
    Asset(message:String);

    /** An error that occurred while processing an image. */
    Image(message:String);

    /** An error that occurred while processing an SVG. */
    Usvg(message:String);

}

class ImageCacheErrorTools {

    public static function toString(self:ImageCacheError):String {
        return switch self {
            case Other(message): 'error: $message';
            case Io(message): 'IO error: $message';
            case BadStatus(uri, status, body): 'unexpected http status for $uri: ${statusToString(status)}, body: $body';
            case Asset(message): 'asset error: $message';
            case Image(message): 'image error: $message';
            case Usvg(message): 'svg error: $message';
        }
    }

    /**
     * Rust `http::StatusCode` display: the code and its canonical reason
     * (`404 Not Found`), or `<unknown status code>`.
     */
    public static function statusToString(status:Int):String {
        final reason = switch status {
            case 100: 'Continue';
            case 101: 'Switching Protocols';
            case 102: 'Processing';
            case 103: 'Early Hints';
            case 200: 'OK';
            case 201: 'Created';
            case 202: 'Accepted';
            case 203: 'Non Authoritative Information';
            case 204: 'No Content';
            case 205: 'Reset Content';
            case 206: 'Partial Content';
            case 207: 'Multi-Status';
            case 208: 'Already Reported';
            case 226: 'IM Used';
            case 300: 'Multiple Choices';
            case 301: 'Moved Permanently';
            case 302: 'Found';
            case 303: 'See Other';
            case 304: 'Not Modified';
            case 305: 'Use Proxy';
            case 307: 'Temporary Redirect';
            case 308: 'Permanent Redirect';
            case 400: 'Bad Request';
            case 401: 'Unauthorized';
            case 402: 'Payment Required';
            case 403: 'Forbidden';
            case 404: 'Not Found';
            case 405: 'Method Not Allowed';
            case 406: 'Not Acceptable';
            case 407: 'Proxy Authentication Required';
            case 408: 'Request Timeout';
            case 409: 'Conflict';
            case 410: 'Gone';
            case 411: 'Length Required';
            case 412: 'Precondition Failed';
            case 413: 'Payload Too Large';
            case 414: 'URI Too Long';
            case 415: 'Unsupported Media Type';
            case 416: 'Range Not Satisfiable';
            case 417: 'Expectation Failed';
            case 418: "I'm a teapot";
            case 421: 'Misdirected Request';
            case 422: 'Unprocessable Entity';
            case 423: 'Locked';
            case 424: 'Failed Dependency';
            case 425: 'Too Early';
            case 426: 'Upgrade Required';
            case 428: 'Precondition Required';
            case 429: 'Too Many Requests';
            case 431: 'Request Header Fields Too Large';
            case 451: 'Unavailable For Legal Reasons';
            case 500: 'Internal Server Error';
            case 501: 'Not Implemented';
            case 502: 'Bad Gateway';
            case 503: 'Service Unavailable';
            case 504: 'Gateway Timeout';
            case 505: 'HTTP Version Not Supported';
            case 506: 'Variant Also Negotiates';
            case 507: 'Insufficient Storage';
            case 508: 'Loop Detected';
            case 510: 'Not Extended';
            case 511: 'Network Authentication Required';
            case _: '<unknown status code>';
        }
        return '$status $reason';
    }

}

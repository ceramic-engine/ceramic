package backend;

import haxe.io.Bytes;

/**
 * Low-level HTTP response data structure used by backend implementations.
 * 
 * This class represents the raw response data returned by platform-specific
 * HTTP implementations before any high-level processing. It contains the
 * essential response information that all platforms must provide.
 * 
 * The backend response is used internally by the HTTP plugin and is wrapped
 * by the higher-level ceramic.HttpResponse which provides additional
 * conveniences and processing.
 * 
 * Content handling at the backend level:
 * - Text content is provided via the `content` field
 * - Binary content is provided via the `binaryContent` field
 * - The decision of which field to populate is made by the platform implementation
 *   based on the response's Content-Type header
 * 
 * This class is primarily used by platform-specific backend implementations
 * and should not be used directly by application code.
 */
@:structInit
class HttpResponse {

    /** HTTP status code returned by the server (e.g., 200, 404, 500) */
    public var status:Int;

    /** 
     * Response content as a string for text responses.
     * This may contain trailing newlines that are cleaned up by higher-level processing.
     */
    public var content:String;

    /** 
     * Response content as raw bytes for binary responses.
     * Defaults to null for text responses.
     */
    public var binaryContent:Bytes = null;

    /** 
     * Error message for failed requests.
     * Defaults to null for successful requests.
     */
    public var error:String = null;

    /**
     * HTTP response headers as a flat array: [key1, value1, key2, value2, ...].
     * This format allows multiple headers with the same name.
     * Header names may not be normalized at this level.
     */
    public var headers:Array<String>;

    /**
     * Returns a string representation of this backend HTTP response for debugging.
     * 
     * Note: For binary content, only the byte length is shown to avoid large output.
     * 
     * @return A formatted string showing the response status, content info, headers, and error
     */
    function toString() {
        return '' + {
            status: status,
            content: content,
            binaryContent: (binaryContent != null ? binaryContent.length : null),
            headers: headers,
            error: error
        };
    }

}

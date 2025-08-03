package ceramic;

import haxe.io.Bytes;

/**
 * HTTP response data structure containing the complete response from an HTTP request.
 * 
 * This class encapsulates all data returned from an HTTP request including status codes,
 * response content (both text and binary), headers, and error information. The response
 * automatically handles content type detection and provides the appropriate content format.
 * 
 * Content handling:
 * - Text responses (based on MIME type) are available via the `content` property
 * - Binary responses are available via the `binaryContent` property
 * - Only one of `content` or `binaryContent` will be non-null based on the response type
 * 
 * Example usage:
 * ```haxe
 * Http.request(options, function(response:HttpResponse) {
 *     if (response.status >= 200 && response.status < 300) {
 *         if (response.content != null) {
 *             trace("Text response: " + response.content);
 *         } else if (response.binaryContent != null) {
 *             trace("Binary response: " + response.binaryContent.length + " bytes");
 *         }
 *     } else {
 *         trace("Error: " + response.status + " - " + response.error);
 *     }
 * });
 * ```
 */
@:structInit
class HttpResponse {

    /** 
     * HTTP status code returned by the server.
     * Common values: 200 (OK), 404 (Not Found), 500 (Internal Server Error), etc.
     */
    public var status:Int;

    /** 
     * Response content as a string for text-based responses.
     * This is null for binary responses or when an error occurred.
     * The content is automatically decoded based on the response's Content-Type header.
     */
    public var content:String;

    /** 
     * Response content as raw bytes for binary responses.
     * This is null for text-based responses or when an error occurred.
     * Use this for images, files, or other non-text data.
     */
    public var binaryContent:Bytes;

    /** 
     * Error message if the request failed.
     * This is null for successful requests.
     * Contains details about network errors, timeouts, or other failure reasons.
     */
    public var error:String = null;

    /** 
     * Map of HTTP response headers with properly formatted keys.
     * Header names are normalized to proper case (e.g., "Content-Type").
     * Common headers include Content-Type, Content-Length, Set-Cookie, etc.
     */
    public var headers:Map<String,String>;

    /**
     * Returns a string representation of this HTTP response for debugging purposes.
     * 
     * @return A formatted string showing the response status, content info, headers, and error
     */
    function toString() {
        return '' + {
            status: status,
            content: content,
            binaryContent: binaryContent,
            headers: headers,
            error: error
        };
    }

}

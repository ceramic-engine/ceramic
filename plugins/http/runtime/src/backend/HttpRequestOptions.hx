package backend;

/**
 * Low-level HTTP request options used by the backend HTTP implementation.
 * 
 * This typedef defines the core parameters required for making HTTP requests
 * at the backend level. It provides the minimal set of options needed across
 * all platform implementations without any high-level conveniences.
 * 
 * These options are used directly by the platform-specific HTTP implementations
 * and are extended by the higher-level ceramic.HttpRequestOptions for additional
 * functionality like automatic parameter encoding.
 * 
 * All properties except `url` are optional and have sensible defaults:
 * - method defaults to GET
 * - headers defaults to empty map
 * - content defaults to null (no body)
 * - timeout defaults to platform-specific default
 * 
 * Example usage:
 * ```haxe
 * var options:HttpRequestOptions = {
 *     url: "https://api.example.com/data",
 *     method: POST,
 *     headers: ["Content-Type" => "application/json"],
 *     content: '{"key": "value"}',
 *     timeout: 30
 * };
 * ```
 */
typedef HttpRequestOptions = {

    /** The target URL for the HTTP request. This is the only required field. */
    var url:String;

    /** The HTTP method to use (GET, POST, PUT, DELETE). Defaults to GET if not specified. */
    @:optional var method:ceramic.HttpMethod;

    /** Map of HTTP headers to include in the request. Header names should be properly formatted. */
    @:optional var headers:Map<String,String>;

    /** Raw string content to send in the request body. Used for POST/PUT requests. */
    @:optional var content:String;

    /** Request timeout in seconds. If not specified, uses platform-specific default timeout. */
    @:optional var timeout:Int;

}

package ceramic;

/**
 * High-level HTTP request options that extend the backend options with additional convenience features.
 * 
 * This typedef extends the low-level backend.HttpRequestOptions with higher-level functionality
 * such as automatic parameter encoding. It provides a more convenient interface for common
 * HTTP request patterns while maintaining compatibility with the underlying backend implementation.
 * 
 * Inherited from backend.HttpRequestOptions:
 * - url: The target URL for the HTTP request
 * - method: The HTTP method to use (GET, POST, PUT, DELETE)
 * - headers: Map of HTTP headers to include in the request
 * - content: Raw string content to send in the request body
 * - timeout: Request timeout in seconds
 * 
 * Additional features:
 * - params: Key-value parameters that are automatically encoded based on the HTTP method
 * 
 * Parameter encoding behavior:
 * - For GET requests: Parameters are appended to the URL as query string
 * - For POST requests: Parameters are form-encoded and sent in the request body
 * - For other methods: Parameters are ignored (with a warning)
 * 
 * Example usage:
 * ```haxe
 * var options:HttpRequestOptions = {
 *     url: "https://api.example.com/search",
 *     method: GET,
 *     params: ["q" => "search term", "limit" => "10"],
 *     headers: ["User-Agent" => "MyApp/1.0"],
 *     timeout: 30
 * };
 * ```
 */
typedef HttpRequestOptions = {

    > backend.HttpRequestOptions,

    /** 
     * Optional key-value parameters that are automatically encoded based on the HTTP method.
     * For GET requests, these are appended to the URL as query parameters.
     * For POST requests, these are form-encoded and sent in the request body.
     * For other methods, these parameters are ignored with a warning.
     */
    @:optional var params:Map<String,String>;

}

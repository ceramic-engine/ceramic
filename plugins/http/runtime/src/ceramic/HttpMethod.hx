package ceramic;

/**
 * HTTP request method enumeration supporting the most common HTTP verbs.
 * 
 * This enum abstract provides type-safe HTTP method constants that can be used
 * with the Ceramic HTTP plugin. All methods are backed by their standard
 * string representations and can be converted to/from strings automatically.
 * 
 * Supported methods:
 * - GET: Retrieve data from a server
 * - POST: Send data to create or modify resources
 * - PUT: Update or replace resources
 * - DELETE: Remove resources
 * 
 * Example usage:
 * ```haxe
 * var method:HttpMethod = GET;
 * var methodString:String = method; // Implicit conversion to "GET"
 * var fromString:HttpMethod = "POST"; // Implicit conversion from string
 * ```
 */
enum abstract HttpMethod(String) from String to String {

    /** HTTP GET method - used for retrieving data from a server */
    var GET = "GET";

    /** HTTP POST method - used for sending data to create or modify resources */
    var POST = "POST";

    /** HTTP PUT method - used for updating or replacing resources */
    var PUT = "PUT";

    /** HTTP DELETE method - used for removing resources */
    var DELETE = "DELETE";

}

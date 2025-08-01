package spec;

import backend.HttpRequestOptions;
import backend.HttpResponse;

/**
 * Backend interface for HTTP networking operations.
 * 
 * This interface provides HTTP client functionality for making web requests.
 * It's available when the http plugin is enabled in ceramic.yml.
 * 
 * The implementation handles platform-specific networking APIs and provides
 * a unified interface for GET, POST, PUT, DELETE and other HTTP methods.
 * 
 * Used by the ceramic.Http class to provide high-level HTTP functionality.
 */
interface Http {

    /**
     * Performs an HTTP request with the specified options.
     * 
     * This is a flexible method that supports all HTTP methods, custom headers,
     * request bodies, and various response types. The request is performed
     * asynchronously and the callback is invoked when complete.
     * 
     * @param options The request configuration including URL, method, headers, body, etc.
     * @param done Callback invoked with the response (or error response on failure)
     */
    function request(options:HttpRequestOptions, done:HttpResponse->Void):Void;

}

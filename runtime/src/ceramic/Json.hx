package ceramic;

/**
 * JSON utility class that provides a unified interface for JSON operations across all Ceramic targets.
 * 
 * This class wraps the standard Haxe JSON functionality, ensuring consistent behavior
 * when serializing and deserializing data structures in Ceramic applications.
 * All methods are inlined for optimal performance.
 * 
 * @see ceramic.PersistentData For saving/loading JSON data persistently
 * @see ceramic.Http For sending/receiving JSON over HTTP
 */
class Json {

    /**
     * Converts a Haxe object into a JSON string representation.
     * 
     * This method serializes Haxe objects, arrays, and primitive values into JSON format.
     * The resulting string can be saved to files, sent over network, or stored in databases.
     * 
     * Example usage:
     * ```haxe
     * var data = {
     *     name: "Player",
     *     score: 1000,
     *     items: ["sword", "shield"]
     * };
     * var jsonString = Json.stringify(data);
     * // Result: {"name":"Player","score":1000,"items":["sword","shield"]}
     * 
     * // With formatting:
     * var prettyJson = Json.stringify(data, null, "  ");
     * ```
     * 
     * @param value The value to convert to JSON. Can be any Haxe object, array, or primitive.
     *              Objects with circular references will cause an error.
     * @param replacer Optional function to transform values during serialization.
     *                 Called for each property with (key, value) and should return the transformed value.
     *                 Return `null` to exclude a property from the output.
     * @param space Optional string or number of spaces for pretty-printing.
     *              Pass "  " for 2-space indentation or "\t" for tabs.
     *              If null or omitted, produces compact JSON without whitespace.
     * @return The JSON string representation of the value
     */
    inline static public function stringify(value:Dynamic, ?replacer:(key:Dynamic, value:Dynamic) -> Dynamic, ?space:String):String {

        return haxe.Json.stringify(value, replacer, space);

    }

    /**
     * Parses a JSON string and returns the corresponding Haxe value.
     * 
     * This method deserializes JSON strings into native Haxe objects and arrays.
     * The resulting value can be cast to specific types or accessed dynamically.
     * 
     * Example usage:
     * ```haxe
     * var jsonString = '{"name":"Player","score":1000}';
     * var data = Json.parse(jsonString);
     * trace(data.name); // "Player"
     * trace(data.score); // 1000
     * 
     * // Type-safe access:
     * var player:PlayerData = cast Json.parse(jsonString);
     * ```
     * 
     * Note: This method throws an exception if the JSON string is malformed.
     * Consider wrapping calls in try-catch blocks when parsing untrusted input:
     * ```haxe
     * try {
     *     var data = Json.parse(untrustedJson);
     * } catch (e:Dynamic) {
     *     trace("Invalid JSON: " + e);
     * }
     * ```
     * 
     * @param text The JSON string to parse. Must be valid JSON format.
     * @return The parsed value as a Dynamic object. Arrays become Array<Dynamic>,
     *         objects become anonymous structures, primitives retain their types.
     * @throws String If the JSON string is malformed or contains syntax errors
     */
    inline static public function parse(text:String):Dynamic {

        return haxe.Json.parse(text);

    }

}
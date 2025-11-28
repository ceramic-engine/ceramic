package ceramic;

/**
 * A collection of HTTP headers that supports multiple values for the same header key.
 *
 * Unlike Map<String, String>, this type allows adding the same header multiple times,
 * which is necessary for headers like Set-Cookie that can appear multiple times in
 * HTTP responses.
 *
 * The underlying storage is a flat array of strings in the format:
 * [key1, value1, key2, value2, ...]
 *
 * Example usage:
 * ```haxe
 * var headers = new HttpHeaders();
 * headers.add("Content-Type", "application/json");
 * headers.add("Set-Cookie", "session=abc123");
 * headers.add("Set-Cookie", "user=john");  // Same header, different value
 *
 * for (header in headers) {
 *     trace(header.key + ": " + header.value);
 * }
 * ```
 */
abstract HttpHeaders(Array<String>) {

    public function new() {
        this = [];
    }

    /**
     * Adds a header with the given name and value.
     * Multiple headers with the same name can be added.
     *
     * @param name The header name (e.g., "Content-Type", "Set-Cookie")
     * @param value The header value
     */
    public function add(name:String, value:String):Void {
        this.push(name);
        this.push(value);
    }

    /**
     * Removes all headers with the given name.
     *
     * @param name The header name to remove
     */
    public function remove(name:String):Void {
        var i:Int = 0;
        while (i < this.length) {
            if (this[i] == name) {
                this.splice(i, 2);
            } else {
                i += 2;
            }
        }
    }

    /**
     * Returns an iterator for iterating over all headers as key-value pairs.
     * This enables the `for (header in headers)` syntax.
     */
    public inline function keyValueIterator():HttpHeadersKeyValueIterator {
        return new HttpHeadersKeyValueIterator(this);
    }

    /**
     * Returns the underlying array representation.
     * Format: [key1, value1, key2, value2, ...]
     */
    public inline function toArray():Array<String> {
        return this;
    }

}

/**
 * Iterator for HttpHeaders that yields {key, value} pairs.
 */
private class HttpHeadersKeyValueIterator {

    var array:Array<String>;
    var index:Int;

    public inline function new(array:Array<String>) {
        this.array = array;
        this.index = 0;
    }

    public inline function hasNext():Bool {
        return index < array.length;
    }

    public inline function next():{key:String, value:String} {
        final key = array[index];
        index++;
        final value = array[index];
        index++;
        return {key: key, value: value};
    }

}

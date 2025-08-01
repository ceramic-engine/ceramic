package ceramic;

import haxe.DynamicAccess;

using StringTools;
#if (ceramic && !macro)
import ceramic.Shortcuts.*;
#end


/**
 * CSV parsing and generation utilities with proper escaping and quote handling.
 * 
 * This class provides robust CSV parsing that handles:
 * - Automatic delimiter detection (comma or semicolon)
 * - Quoted values with embedded delimiters
 * - Escaped quotes within quoted values
 * - Multi-line values within quotes
 * - Dynamic field discovery from data
 * 
 * ## Features
 * 
 * - **Auto-detection**: Automatically detects comma or semicolon delimiters
 * - **Proper Escaping**: Handles quoted values and escaped quotes correctly
 * - **Type-safe**: Returns typed DynamicAccess objects for easy field access
 * - **Flexible Output**: Can generate CSV with specific or auto-discovered fields
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Parse CSV string
 * var csv = 'name,age,city\n"John",30,"New York"\n"Jane",25,"San Francisco"';
 * var data = Csv.parse(csv);
 * trace(data[0].name); // "John"
 * 
 * // Generate CSV from objects
 * var items = [
 *     {name: "Alice", score: 95},
 *     {name: "Bob", score: 87}
 * ];
 * var csvString = Csv.stringify(items);
 * ```
 * 
 * @see ceramic.DatabaseAsset For loading CSV files as assets
 */
class Csv {

    /**
     * Parses a CSV string into an array of objects.
     * 
     * Each row (except the header) becomes an object where field names
     * are taken from the first row. The parser automatically detects
     * whether commas or semicolons are used as delimiters.
     * 
     * ## CSV Format Rules
     * 
     * - First row must contain field names
     * - Values containing delimiters or newlines must be quoted
     * - Quotes within quoted values must be escaped as ""
     * - Trailing/leading whitespace is preserved
     * - Empty values are returned as empty strings
     * 
     * @param csv The CSV string to parse
     * @return Array of objects with fields as defined in the header row
     * 
     * @example
     * ```haxe
     * var csv = 'id,name,description\n' +
     *           '1,"Smith, John","Says ""Hello"""\n' +
     *           '2,Jane Doe,Regular description';
     * 
     * var data = Csv.parse(csv);
     * trace(data[0].name); // "Smith, John"
     * trace(data[0].description); // "Says "Hello""
     * ```
     */
    public static function parse(csv:String):Array<DynamicAccess<String>> {

        // Cleanup
        csv = csv.trim();

        // Find separator and keys
        //
        var sep = '';
        var i = 0;
        var c = '';
        var cc = '';
        var len = csv.length;
        var inString = false;
        var val = '';
        var keys = [];

        while (i < len) {
            c = csv.charAt(i);

            if (inString) {
                if (c == '"') {
                    cc = c + csv.charAt(i+1);
                    if (cc == '""') {
                        val += '"';
                        i += 2;
                    } else {
                        inString = false;
                        i++;
                    }
                } else {
                    val += c;
                    i++;
                }
            }
            else if (c == "\n") {
                i++;
                break;
            }
            else if (val == '' && c == '"') {
                inString = true;
                i++;
            }
            else if (sep == '') {
                if (c == ',' || c == ';') {
                    sep = c;
                    keys.push(val.replace("\r",""));
                    val = '';
                }
                else {
                    val += c;
                }
                i++;
            }
            else if (c == sep) {
                keys.push(val.replace("\r",""));
                val = '';
                i++;
            }
            else {
                val += c;
                i++;
            }
        }

        if (val != '') keys.push(val.replace("\r",""));

        // Parse
        //
        inString = false;
        val = '';
        var entry:Dynamic = {};
        var entryHasFields = false;
        var result = [];
        var keyIndex = 0;
        var key = '';
        var tooManyColumnsAt = -1;

        while (i < len) {
            c = csv.charAt(i);

            if (inString) {
                if (c == '"') {
                    cc = c + csv.charAt(i+1);
                    if (cc == '""') {
                        val += '"';
                        i += 2;
                    } else {
                        inString = false;
                        i++;
                    }
                } else {
                    val += c;
                    i++;
                }
            }
            else if (c == "\n") {

                key = keys[keyIndex++];
                if (key != null) {
                    Reflect.setField(entry, key, val.replace("\r",""));
                    entryHasFields = true;
                } else if (tooManyColumnsAt == -1) {
                    tooManyColumnsAt = result.length;
                }
                val = '';

                result.push(entry);
                entryHasFields = false;
                keyIndex = 0;
                entry = {};
                i++;
            }
            else if (val == '' && c == '"') {
                inString = true;
                i++;
            }
            else if (c == sep) {
                key = keys[keyIndex++];
                if (key != null) {
                    Reflect.setField(entry, key, val.replace("\r",""));
                    entryHasFields = true;
                } else if (tooManyColumnsAt == -1) {
                    tooManyColumnsAt = result.length;
                }
                val = '';
                i++;
            }
            else {
                val += c;
                i++;
            }
        }

        key = keys[keyIndex++];
        if (key != null) {
            Reflect.setField(entry, key, val.replace("\r",""));
            entryHasFields = true;
        } else if (tooManyColumnsAt == -1) {
            warning(entry);
            tooManyColumnsAt = result.length;
        }
        val = '';

        if (entryHasFields) {
            result.push(entry);
        }

        if (tooManyColumnsAt >= 0) {
            warning('Malformed CSV: too many columns at row #' + tooManyColumnsAt);
        }

        return result;

    }

    /**
     * Converts an array of objects to CSV format.
     * 
     * Automatically handles escaping of special characters:
     * - Values containing commas, quotes, or newlines are wrapped in quotes
     * - Quotes within values are escaped as double quotes ("")
     * - Field order is determined by the fields parameter or auto-discovered
     * 
     * @param items Array of objects to convert to CSV
     * @param fields Optional array of field names to include in specific order.
     *               If not provided, fields are auto-discovered from all objects.
     * @return CSV string with header row and data rows
     * 
     * @example
     * ```haxe
     * var data = [
     *     {id: 1, name: "John", note: "Says "Hi""},
     *     {id: 2, name: "Jane, MD", note: "Multi\nline"}
     * ];
     * 
     * // Auto-discover fields
     * var csv1 = Csv.stringify(data);
     * 
     * // Specific fields only
     * var csv2 = Csv.stringify(data, ["id", "name"]);
     * ```
     */
    public static function stringify(items:Array<Dynamic>, ?fields:Array<String>):String {

        /**
         * Helper function to add a properly escaped CSV value.
         * Values are quoted and internal quotes are doubled.
         */
        inline function addEscaped(output:StringBuf, input:String) {

            if (input.length == 0) return;
            output.add('"');
            for (i in 0...input.length) {
                var c = input.charAt(i);
                if (c == '"') {
                    output.add('""');
                } else {
                    output.add(c);
                }
            }
            output.add('"');

        }

        if (fields == null) {
            fields = [];
            var usedFields:Map<String,Bool> = new Map();
            for (item in items) {
                for (field in Reflect.fields(item)) {
                    if (!usedFields.exists(field)) {
                        fields.push(field);
                        usedFields.set(field, true);
                    }
                }
            }
        }

        var output = new StringBuf();

        var n = 0;
        for (field in fields) {
            if (n++ > 0) output.add(',');
            addEscaped(output, field);
        }

        for (item in items) {
            output.add("\n");
            n = 0;
            for (field in fields) {
                if (n++ > 0) output.add(',');
                var value:Dynamic = Reflect.field(item, field);
                addEscaped(output, value != null ? Std.string(value) : '');
            }
        }

        return output.toString();

    }

    /**
     * Internal warning function that adapts to the current platform.
     * Uses ceramic logging when available, otherwise falls back to
     * platform-specific console output.
     */
    static function warning(str:String):Void {

#if (!ceramic || macro)

#if sys
        Sys.println(str);
#elseif web
        untyped console.log(str);
#else
        trace(str);
#end

#else

        log.warning(str);

#end

    }

}

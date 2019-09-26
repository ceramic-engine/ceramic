package ceramic;

import haxe.DynamicAccess;

#if (ceramic && !macro)
import ceramic.Shortcuts.*;
#end

using StringTools;

/** Utilities to parse CSV and related */
class Csv {

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

    } //parse

    public static function stringify(items:Array<Dynamic>, ?fields:Array<String>):String {

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

        } //addEscaped

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
                var value = Reflect.field(item, field);
                addEscaped(output, value != null ? Std.string(value) : '');
            }
        }

        return output.toString();

    } //stringify

#if (!ceramic || macro)

    static function warning(str:String):Void {

#if sys
        Sys.println(str);
#elseif web
        untyped console.log(str);
#else
        trace(str);
#end

    } //warning

#end

}

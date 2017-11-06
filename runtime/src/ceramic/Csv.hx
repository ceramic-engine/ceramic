package ceramic;

import haxe.DynamicAccess;
import ceramic.Shortcuts.*;

using unifill.Unifill;
using StringTools;

/** Utilities to parse CSV and related */
class Csv {

    public static function parse(csv:String):Array<DynamicAccess<String>> {

        // Cleanup
        csv = csv.replace("\r", '').trim();

        // Find separator and keys
        //
        var sep = '';
        var i = 0;
        var c = '';
        var cc = '';
        var len = csv.uLength();
        var inString = false;
        var val = '';
        var keys = [];

        while (i < len) {
            c = csv.uCharAt(i);

            if (inString) {
                if (c == '"') {
                    cc = csv.uSubstr(i, 2);
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
                    sep = ',';
                    keys.push(val);
                    val = '';
                }
                else {
                    val += c;
                }
                i++;
            }
            else if (c == sep) {
                keys.push(val);
                val = '';
                i++;
            }
            else {
                i++;
            }
        }

        if (val != '') keys.push(val);

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
            c = csv.uCharAt(i);

            if (inString) {
                if (c == '"') {
                    cc = csv.uSubstr(i, 2);
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
                    Reflect.setField(entry, key, val);
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
                    Reflect.setField(entry, key, val);
                    entryHasFields = true;
                } else if (tooManyColumnsAt == -1) {
                    tooManyColumnsAt = result.length;
                }
                val = '';
                i++;
            }
            else {
                i++;
            }
        }

        key = keys[keyIndex++];
        if (key != null && val != '') {
            Reflect.setField(entry, key, val);
            entryHasFields = true;
        } else if (tooManyColumnsAt == -1) {
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

}

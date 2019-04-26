package tools;

import haxe.io.Path;

using StringTools;

class Hxml {

    /** Parse raw HXML content and return an array of strings. */
    public static function parse(rawHxml:String):Array<String> {

        var args = [];
        var i = 0;
        var len = rawHxml.length;
        var currentArg = '';
        var prevArg = null;
        var numberOfParens = 0;
        var c, m0;

        while (i < len) {
            c = rawHxml.charAt(i);

            if (c == '(') {
                if (prevArg == '--macro') {
                    numberOfParens++;
                }
                currentArg += c;
                i++;
            }
            else if (numberOfParens > 0 && c == ')') {
                numberOfParens--;
                currentArg += c;
                i++;
            }
            else if (c == '"' || c == '\'') {
                if (RE_BEGINS_WITH_STRING.match(rawHxml.substr(i))) {
                    m0 = RE_BEGINS_WITH_STRING.matched(0);
                    currentArg += m0;
                    i += m0.length;
                }
                else {
                    // This should not happen, but if it happens, just add the character
                    currentArg += c;
                    i++;
                }
            }
            else if (c.trim() == '') {
                if (numberOfParens == 0) {
                    if (currentArg.length > 0) {
                        prevArg = currentArg;
                        currentArg = '';
                        args.push(prevArg);
                    }
                }
                else {
                    currentArg += c;
                }
                i++;
            }
            else {
                currentArg += c;
                i++;
            }

        }

        if (currentArg.length > 0) {
            args.push(currentArg);
        }

        return args;
    }

    public static function formatAndChangeRelativeDir(hxmlData:Array<String>, originalDir:String, targetDir:String):Array<String> {

        // Add required hxml
        var updatedData = [];

        // Convert relative paths to absolute ones
        var i = 0;
        while (i < hxmlData.length) {

            var item = hxmlData[i];

            if (item.startsWith('-') || item.endsWith('.hxml')) {
                if (updatedData.length > 0) updatedData.push("\n");
            }

            // Update relative path to sub-hxml files
            if (item.endsWith('.hxml')) {
                var path = hxmlData[i];

                if (!Path.isAbsolute(path)) {
                    // Make this path absolute to make it work from project's CWD
                    path = Path.normalize(Path.join([originalDir, path]));

                    // Remove path prefix
                    if (path.startsWith(targetDir + '/')) {
                        path = path.substr(targetDir.length + 1);
                    }
                }

                updatedData.push(path);
            }
            else {
                updatedData.push(item);
            }

            if (item == '-cp' || item == '-cpp' || item == '-js' || item == '-swf') {
                i++;

                var path = hxmlData[i];
                if (!Path.isAbsolute(path)) {
                    // Make this path absolute to make it work from project's CWD
                    path = Path.normalize(Path.join([originalDir, path]));

                    // Remove path prefix for -cpp/-js/-swf
                    if (item != '-cp' && path.startsWith(targetDir + '/')) {
                        path = path.substr(targetDir.length + 1);
                    }
                }

                updatedData.push(path);
            }

            i++;
        }

        return updatedData;
    }

    public static function convertLibsToCps(hxmlData:Array<String>):Array<String> {

        var updatedData = [];

        // TODO

        return updatedData;

    } //convertLibsToCps

    /** Match any single/double quoted string */
    static var RE_BEGINS_WITH_STRING:EReg = ~/^(?:"(?:[^"\\]*(?:\\.[^"\\]*)*)"|'(?:[^'\\]*(?:\\.[^'\\]*)*)')/;

} //Hxml

package elements;

import ceramic.Slug;
import ceramic.Utils;

@:allow(elements.SanitizeTextField)
class TextUtils {

    static final RE_PREFIXED = ~/^(.*?)([0-9]+)$/;

    static final RE_SPACES = ~/\s+/;

    public static function toFieldLabel(str:String):String {

        var result = new StringBuf();

        for (i in 0...str.length) {
            var char = str.charAt(i);

            if (i == 0) {
                result.add(char.toUpperCase());
            }
            else if (char.toUpperCase() == char) {
                result.add(' ');
                result.add(char);
            }
            else {
                result.add(char);
            }
        }

        return result.toString();

    }

    public static function compareStrings(a:String, b:String) {
        a = a.toUpperCase();
        b = b.toUpperCase();

        if (a < b) {
          return -1;
        }
        else if (a > b) {
          return 1;
        }
        else {
          return 0;
        }
    }

    public static function compareStringFirstEntries(aArray:Array<Dynamic>, bArray:Array<Dynamic>) {
        var a:String = aArray[0];
        var b:String = bArray[0];

        a = a.toUpperCase();
        b = b.toUpperCase();

        if (a < b) {
          return -1;
        }
        else if (a > b) {
          return 1;
        }
        else {
          return 0;
        }
    }

    /** Transforms `SOME_IDENTIFIER` to `SomeIdentifier` */
    public static function upperCaseToCamelCase(input:String, firstLetterUppercase:Bool = true, ?between:String):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var nextLetterUpperCase = firstLetterUppercase;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '_') {
                nextLetterUpperCase = true;
            }
            else if (nextLetterUpperCase) {
                nextLetterUpperCase = false;
                if (i > 0 && between != null) {
                    res.add(between);
                }
                res.add(c.toUpperCase());
            }
            else {
                res.add(c.toLowerCase());
            }

            i++;
        }

        return res.toString();

    }

    public static function getPrefix(str:String):String {

        if (RE_PREFIXED.match(str)) {
            str = RE_PREFIXED.matched(1);
        }
        while (str.length > 0 && str.charAt(str.length - 1) == '_') {
            str = str.substring(0, str.length - 1);
        }
        return str;

    }

    public static function uppercasePrefixFromClass(className:String):String {

        var parts = className.split('.');
        var str = parts[parts.length-1];
        str = Utils.camelCaseToUpperCase(str);
        while (str.length > 0 && str.charAt(str.length - 1) == '_') {
            str = str.substring(0, str.length - 1);
        }
        return str;

    }

    static final _slugUpperCase:SlugOptions = {
        lower: false,
        replacement: '_',
        remove: Slug.RE_SLUG_REMOVE_CHARS
    };

    public static function slugifyUpperCase(str:String):String {

        str = RE_SPACES.replace(str, '_');
        str = Slug.encode(str, _slugUpperCase);
        return str;

    }

}
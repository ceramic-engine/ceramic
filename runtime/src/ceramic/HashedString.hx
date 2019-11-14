package ceramic;

import ceramic.Utils;

using StringTools;

class HashedString {

    public static function encode(str:String):String {

        var hashCode = Utils.hashCode(str);
        var len = str.length;

        return hashCode + ':' + len + ':' + str;

    } //append

    public static function decode(encoded:String):String {

        var result = new StringBuf();

        var i = 0;
        var len = encoded.length;

        var parsingHash = false;

        var hasHash = false;
        var hash:Int = -1;

        while (i < len) {
            var charCode = encoded.charCodeAt(i);

            /*if (parsingHash) {
                decodeUntil(':'.code);
            }*/
        }

    } //decode

} //HashedString

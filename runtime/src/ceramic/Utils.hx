package ceramic;

import ceramic.internal.PlatformSpecific;

import haxe.rtti.CType;

using StringTools;

/** Various utilities. Some of them are used by ceramic itself or its backends. */
class Utils {

    public static function realPath(path:String):String {

        path = haxe.io.Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            haxe.io.Path.join([ceramic.App.app.settings.assetsPath, path]);

        return path;

    } //realPath

	inline public static function getRtti<T>(c:Class<T>):Classdef {

		return PlatformSpecific.getRtti(c);

	} //getRtti

    inline public static function uniqueId():String {

        return base62Id() + base62Id() + base62Id() + base62Id() + base62Id() + base62Id() + base62Id() + base62Id();

    } //uniqueId

    inline public static function base62Id(?val:Null<Int>):String {

        // http://www.anotherchris.net/csharp/friendly-unique-id-generation-part-2/#base62
        // Haxe snippet from Luxe

        if (val == null) {
            val = Std.random(0x7fffffff);
        }

        function toChar(value:Int):String {
            if (value > 9) {
                var ascii = (65 + (value - 10));
                if (ascii > 90) { ascii += 6; }
                return String.fromCharCode(ascii);
            } else return Std.string(value).charAt(0);
        } //toChar

        var r = Std.int(val % 62);
        var q = Std.int(val / 62);
        if (q > 0) return base62Id(q) + toChar(r);
        else return Std.string(toChar(r));

    } //base62Id

} //Utils

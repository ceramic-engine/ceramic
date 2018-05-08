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

    static var _nextUniqueIntCursor:Int = 0;
    static var _nextUniqueInt0:Int = Std.random(0x7fffffff);
    static var _nextUniqueInt1:Int = Std.int(Date.now().getTime() * 0.0001);
    static var _nextUniqueInt2:Int = Std.random(0x7fffffff);
    static var _nextUniqueInt3:Int = Std.random(0x7fffffff);

    public static function uniqueId():String {

        switch (_nextUniqueIntCursor) {
            case 0:
                _nextUniqueInt0 = (_nextUniqueInt0 + 1) % 0x7fffffff;
            case 1:
                _nextUniqueInt1 = (_nextUniqueInt1 + 1) % 0x7fffffff;
            case 2:
                _nextUniqueInt2 = (_nextUniqueInt2 + 1) % 0x7fffffff;
            case 3:
                _nextUniqueInt3 = (_nextUniqueInt3 + 1) % 0x7fffffff;
        }
        _nextUniqueIntCursor = (_nextUniqueIntCursor + 1) % 4;

        return base62Id(_nextUniqueInt0) + base62Id() + base62Id(_nextUniqueInt1) + base62Id() + base62Id(_nextUniqueInt2) + base62Id() + base62Id(_nextUniqueInt3);

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

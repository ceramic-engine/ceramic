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

} //Utils

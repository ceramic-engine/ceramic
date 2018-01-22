package ceramic;

import haxe.rtti.CType;
import haxe.rtti.Rtti;

#if cpp
import sys.io.File;
import sys.FileSystem;
import haxe.crypto.Md5;
#end

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

	public static function getRtti<T>(c:Class<T>):Classdef {
#if (cpp && snow)
		// For some unknown reason, app is crashing on some c++ platforms when trying to access `__rtti` field
		// As a workaround, we export rtti data into external asset files at compile time and read them
		// at runtime to get the same information.
		var rtti = null;
		var cStr = '' + c;
        var root = '';
#if (ios || tvos)
        root = 'assets/';
#end
		var xmlPath = haxe.io.Path.join([root, 'assets', 'rtti', Md5.encode(cStr + '.xml')]);
		if (FileSystem.exists(xmlPath)) {
			rtti = File.getContent(xmlPath);
		}
		if (rtti == null) {
			throw 'Class ${Type.getClassName(c)} has no RTTI information, consider adding @:rtti';
		}
		var x = Xml.parse(rtti).firstElement();
		var infos = new haxe.rtti.XmlParser().processElement(x);
		switch (infos) {
			case TClassdecl(c): return c;
			case t: throw 'Enum mismatch: expected TClassDecl but found $t';
		}
#else
		return Rtti.getRtti(c);
#end
	}

} //Utils

package ceramic.internal;

import haxe.rtti.CType;
import haxe.rtti.Rtti;
#if (bind && android && snow)
import bind.java.Support;
#end
#if cpp
import sys.io.File;
import sys.FileSystem;
import haxe.crypto.Md5;
#end

/** An internal class that encapsulate platform-specific code.
    We usually want platform-specific code to be located in a backend,
    but it may happen that sometimes creating a backend interface is overkill.
    That's where this comes handy. */
class PlatformSpecific {

    public static function postAppInit():Void {

        #if (bind && android && snow)
        // A hook to flush java runnables that need to be run from Haxe thread
        ceramic.App.app.onUpdate(null, function(_) {
            bind.java.Support.flushRunnables();
        });
        #end

    } //postAppInit

    public static function getRtti<T>(c:Class<T>):Classdef {
        /*#if (cpp && snow)
            // For some unknown reason, app is crashing on some c++ platforms when trying to access `__rtti` field
            // As a workaround, we export rtti data into external asset files at compile time and read them
            // at runtime to get the same information.
            var rtti = null;
            var cStr = '' + c;
            var root = '';
            #if (ios || tvos)
            root = 'assets/';
            #end
            var xmlPath = ceramic.Path.join([root, 'assets', 'rtti', Md5.encode(cStr + '.xml')]);
            rtti = @:privateAccess Luxe.snow.io.module._data_load(xmlPath).toBytes().toString();

            if (rtti == null) {
                throw 'Class ${Type.getClassName(c)} has no RTTI information, consider adding @:rtti';
            }

            var x = Xml.parse(rtti).firstElement();
            var infos = new haxe.rtti.XmlParser().processElement(x);
            switch (infos) {
                case TClassdecl(c): return c;
                case t: throw 'Enum mismatch: expected TClassDecl but found $t';
            }
            #else */

        return Rtti.getRtti(c);
        //#end
    }

} //PlatformSpecific

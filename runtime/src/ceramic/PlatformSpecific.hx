package ceramic;

import haxe.rtti.CType;
import haxe.rtti.Rtti;
import haxe.io.Bytes;
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

    }

    /**
     * Read a string from an asset file, synchronously.
     * Warning: not available on every targets
     * @return String
     */
    public static function readStringFromAsset(assetPath:String):String {

        #if (cpp && snow)

        var root = 'assets';
        #if (ios || tvos)
        root = 'assets/assets/';
        #end

        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            root += assetsPrefix;
        }

        var filePath = ceramic.Path.join([root, assetPath]);
        var handle = @:privateAccess Luxe.snow.io.module._data_load(filePath);
        if (handle != null)
            return handle.toBytes().toString();
        else
            return null;

        #else
        return null;
        #end

    }
    
    /**
     * Read bytes from an asset file, synchronously.
     * Warning: not available on every targets
     * @return String
     */
    public static function readBytesFromAsset(assetPath:String):Bytes {

        #if (cpp && snow)

        var root = 'assets';
        #if (ios || tvos)
        root = 'assets/assets/';
        #end

        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            assetPath = assetsPrefix + assetPath;
        }
        
        var filePath = ceramic.Path.join([root, assetPath]);
        var handle = @:privateAccess Luxe.snow.io.module._data_load(filePath);
        if (handle != null)
            return handle.toBytes();
        else
            return null;

        #else
        return null;
        #end

    }

    /**
     * Returns assets paths on disk (if any)
     * Warning: not available on every targets
     * @return String
     */
    public static function getAssetsPath():String {

        #if android

        return null;

        #elseif (cpp && snow)

        var root = 'assets/';
        #if (ios || tvos)
        root = 'assets/assets/';
        #end

        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            root += assetsPrefix;
        }
        
        var filePath = ceramic.Path.join([sdl.SDL.getBasePath(), root]);

        return filePath;

        #else
        return null;
        #end

    }

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

    #if (web && ceramic_use_electron)
    static var testedElectronAvailability:Bool = false;
    static var electron:Null<Dynamic> = null;

    inline public static function resolveElectron():Null<Dynamic> {

        if (!testedElectronAvailability) {
            testedElectronAvailability = true;
            try {
                electron = untyped __js__("require('electron')");
            }
            catch (e:Dynamic) {}
        }

        return electron;

    }

    public static function nodeRequire(module:String):Null<Dynamic> {

        resolveElectron();
    
        if (electron != null) {
    
            var required:Dynamic = untyped __js__("{0}.remote.require({1})", electron, module);
            return required;

        }
        else {
            return null;
        }
            
    }

    public static function electronRemote():Null<Dynamic> {

        resolveElectron();
    
        if (electron != null) {
            return electron.remote;
        }
        else {
            return null;
        }

    }

    #elseif js
    public static function nodeRequire(module:String):Dynamic {
        #if (node || nodejs || hxnodejs)
        return js.Lib.require(module);
        #else
        return null;
        #end
    }
    #end

}

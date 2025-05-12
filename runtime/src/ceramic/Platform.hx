package ceramic;

import ceramic.Shortcuts.*;
import haxe.io.Bytes;
import haxe.rtti.CType;
import haxe.rtti.Rtti;
#if (bind && android && clay)
import bindhx.java.Support;
#end
#if (bind && ios && clay)
import bindhx.objc.Support;
#end
#if cpp
import haxe.crypto.Md5;
import sys.FileSystem;
import sys.io.File;
#end


/**
 * A class that encapsulate platform-specific code.
 * We usually want platform-specific code to be located in a backend,
 * but it may happen that sometimes creating a backend interface is overkill.
 * That's where this comes handy.
 */
class Platform {

    public static function postAppInit():Void {

        #if (bind && android && clay)
        // A hook to flush java runnables that need to be run from Haxe thread
        ceramic.App.app.onUpdate(null, function(_) {
            bindhx.java.Support.flushHaxeQueue();
        });
        #end

        #if (bind && ios && clay)
        // A hook to flush objc callbacks that need to be run from Haxe thread
        ceramic.App.app.onUpdate(null, function(_) {
            bindhx.objc.Support.flushHaxeQueue();
        });
        #end

    }

    /**
     * Read a string from an asset file, synchronously.
     * Warning: not available on every targets
     * @return String
     */
    public static function readStringFromAsset(assetPath:String):String {

        #if (cpp && clay)

        var root = 'assets';

        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            root += assetsPrefix;
        }

        var filePath = ceramic.Path.join([root, assetPath]);
        var fullPath = clay.Clay.app.assets.fullPath(filePath);
        var data = clay.Clay.app.io.loadData(fullPath, false);
        if (data != null)
            return data.toBytes().toString();
        else
            return null;

        #elseif (cpp && snow)

        var root = 'assets';
        #if (ios || tvos)
        root = 'assets/assets/';
        #end

        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            root += assetsPrefix;
        }

        var filePath = ceramic.Path.join([root, assetPath]);
        var handle = @:privateAccess snow.Snow.app.io.module._data_load(filePath);
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

        #if (cpp && clay)

        var root = 'assets';

        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            root += '/' + assetsPrefix;
        }

        var filePath = assetsPrefix != null ? root + assetPath : ceramic.Path.join([root, assetPath]);
        var fullPath = clay.Clay.app.assets.fullPath(filePath);
        var data = clay.Clay.app.io.loadData(fullPath, false);
        if (data != null)
            return data.toBytes();
        else
            return null;

        #elseif (cpp && snow)

        var root = 'assets';
        #if (ios || tvos)
        root = 'assets/assets/';
        #end

        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            assetPath = assetsPrefix + assetPath;
        }

        var filePath = ceramic.Path.join([root, assetPath]);
        var handle = @:privateAccess snow.Snow.app.io.module._data_load(filePath);
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

        #elseif (cpp && clay)

        var root = 'assets';
        var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
        if (assetsPrefix != null) {
            root += assetsPrefix;
        }

        return clay.Clay.app.assets.fullPath(root);

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
    static var testedElectronRemoteAvailability:Bool = false;
    static var _electron:Null<Dynamic> = null;
    static var _electronRemote:Null<Dynamic> = null;

    inline public static function resolveElectron():Null<Dynamic> {

        if (!testedElectronAvailability) {
            testedElectronAvailability = true;
            try {
                final remote = electronRemote();
                _electron = js.Syntax.code("{0}.require('electron')", remote);
            }
            catch (e:Dynamic) {}
        }

        return _electron;

    }

    public static function nodeRequire(module:String):Null<Dynamic> {

        resolveElectron();

        if (_electronRemote != null) {

            var required:Dynamic = js.Syntax.code("{0}.require({1})", _electronRemote, module);
            return required;

        }
        else {
            return null;
        }

    }

    public static function electronRemote():Null<Dynamic> {

        if (!testedElectronRemoteAvailability) {
            testedElectronRemoteAvailability = true;
            try {
                _electronRemote = js.Syntax.code("require('@electron/remote')");
            }
            catch (e:Dynamic) {}
        }

        return _electronRemote;

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

    public static function quit():Void {

        #if clay

        #if (ios || tvos || android)

        log.warning('On mobile platforms, quitting must be triggered from the user or operating system.');

        #else

        clay.Clay.app.shutdown();

        #if (web && ceramic_use_electron)
        var remote = electronRemote();
        if (remote != null) {
            var window = remote.getCurrentWindow();
            if (window != null) {
                window.close();
            }
        }
        #end

        #end

        #elseif unity

        untyped __cs__('UnityEngine.Application.Quit()');

        #elseif (node || nodejs || hxnodejs)

        js.Syntax.code('process.exit(0)');

        #end

    }

    /**
     * Executes the given Ceramic command asynchronously.
     * This will work only on desktop platforms that have a valid Ceramic installation available.
     * When the app has been launched by Ceramic itself, the same CLI tool will be used.
     * Otherwise, it will look for a `ceramic` command available in `PATH`
     * @param cmd The command to run
     * @param args (optional) The command arguments, which will be automatically escaped
     * @param callback The callback, called when the command has finished (or failed)
     */
    public static function runCeramic(args:Array<String>, callback:(code:Int, stdout:String, stderr:String)->Void):Void {

        var cmd = Platform.getEnv('CERAMIC_CLI');
        if (cmd == null)
            cmd = isWindows() ? 'ceramic.exe' : 'ceramic';

        log.debug('ceramic ' + args.join(' '));
        exec(cmd, args, callback);

    }

    public static function getEnv(key:String):String {

        #if ((web && ceramic_use_electron) || node || nodejs || hxnodejs)
        try {
            return js.Syntax.code('process.env[{0}]', key);
        }
        catch (e:Any) {
            return null;
        }
        #elseif (sys || cs)
        return Sys.getEnv(key);
        #else
        return null;
        #end

    }

    public static function isWindows():Bool {

        #if ((web && ceramic_use_electron) || node || nodejs || hxnodejs)
        var isWindows:Bool = false;
        if (_isWindowsValue == 0) {
            try {
                #if (node || nodejs || hxnodejs)
                isWindows = js.Syntax.code('process.platform == "win32"');
                #else
                final os:Dynamic = nodeRequire('os');
                isWindows = os.platform() == 'win32';
                #end
            }
            catch (e:Any) {
                isWindows = false;
            }
            _isWindowsValue = (isWindows ? 1 : -1);
        }
        else {
            isWindows = (_isWindowsValue == 1);
        }
        return isWindows;
        #elseif windows
        return true;
        #elseif sys
        var isWindows:Bool = false;
        if (_isWindowsValue == 0) {
            _isWindowsValue = ((Sys.systemName() == 'Windows') ? 1 : -1);
        }
        return (_isWindowsValue == 1);
        #else
        return false;
        #end

    }

    /**
     * Executes the given command asynchronously
     * @param cmd The command to run
     * @param args (optional) The command arguments, which will be automatically escaped
     * @param callback The callback, called when the command has finished
     */
    public static function exec(cmd:String, ?args:Array<String>, callback:(code:Int, stdout:String, stderr:String)->Void):Void {

        #if ((web && ceramic_use_electron) || node || nodejs || hxnodejs)

        var childProcess = nodeRequire('child_process');

        if (args == null) {
            args = [];
        }

        final isWindows = isWindows();

        var options = {
            shell: isWindows ? (StringTools.endsWith(cmd, '.exe') ? false : true) : false
        };

        if (options.shell) {
            args = [].concat(args);
            for (i in 0...args.length) {
                args[i] = isWindows ? haxe.SysTools.quoteWinArg(args[i], false) : haxe.SysTools.quoteUnixArg(args[i]);
            }
        }

        var proc = childProcess.spawn(cmd, args, options);
        var stdout = new StringBuf();
        var stderr = new StringBuf();
        proc.stdout.on('data', function(data:String) {
            stdout.add(data);
        });
        proc.stderr.on('data', function(data:String) {
            stderr.add(data);
        });
        proc.on('close', function(code:Int) {
            callback(code, stdout.toString(), stderr.toString());
        });
        proc.on('error', function(err:Dynamic) {
            stderr.add(Std.string(err));
            callback(-1, stdout.toString(), stderr.toString());
        });

        #elseif sys

        Runner.runInBackground(() -> {

            final proc = new sys.io.Process(cmd, args, false);
            final code = proc.exitCode();
            final stdout = proc.stdout.readAll().toString();
            final stderr = proc.stderr.readAll().toString();
            proc.close();

            Runner.runInMain(() -> {
                callback(code, stdout, stderr);
                callback = null;
            });

        });

        #else

        static var _execDidLogError = false;
        if (!_execDidLogError) {
            _execDidLogError = true;
            log.error('exec() is not supported on this platform!');
        }
        callback(-1, null, null);

        #end

    }

    private static var _isWindowsValue:Int = 0;
    private static var _execDidLogError:Bool = false;

}

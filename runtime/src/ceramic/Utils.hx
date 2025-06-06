package ceramic;

import ceramic.Assert.assert;
import ceramic.Platform;
import ceramic.Shortcuts.*;
import haxe.CallStack;
import haxe.io.Bytes;
import haxe.rtti.CType;

using StringTools;
using ceramic.Extensions;

/**
 * Various utilities. Some of them are used by ceramic itself or its backends.
 */
class Utils {

    static var RE_ASCII_CHAR = ~/^[a-zA-Z0-9]$/;

    public static function realPath(path:String):String {

        path = ceramic.Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            ceramic.Path.join([ceramic.App.app.settings.assetsPath, path]);

        return path;

    }

    inline public static function getRtti<T>(c:Class<T>):Classdef {

        return Platform.getRtti(c);

    }

    static var _nextUniqueIntCursor:Int = 0;
    static var _nextUniqueInt0:Int = Std.int(Math.random() * 0x7ffffffe);
    static var _nextUniqueInt1:Int = Std.int(Date.now().getTime() * 0.0001);
    static var _nextUniqueInt2:Int = Std.int(Math.random() * 0x7ffffffe);
    static var _nextUniqueInt3:Int = Std.int(Math.random() * 0x7ffffffe);

    #if (cpp || cs || sys)
    static var _uniqueIdMutex:sys.thread.Mutex = new sys.thread.Mutex();
    #end

    /**
     * Provides an identifier which is garanteed to be unique on this local device.
     * It however doesn't garantee that this identifier is not predictable.
     */
    public static function uniqueId():String {

        #if (cpp || cs || sys)
        _uniqueIdMutex.acquire();
        #end

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

        var result = base62Id(_nextUniqueInt0) + '-' + base62Id() + '-' + base62Id(_nextUniqueInt1) + '-' + base62Id() + '-' + base62Id(_nextUniqueInt2) + '-' + base62Id() + '-' + base62Id(_nextUniqueInt3);

        #if (cpp || cs || sys)
        _uniqueIdMutex.release();
        #end

        return result;

    }

    /**
     * Provides a random identifier which should be fairly unpredictable and
     * should have an extremely low chance to provide the same identifier twice.
     */
    public static function randomId(size:Int = 32):String {

        var chars = [];
        while (chars.length < size) {
            var chunk = base62Id();
            for (i in 0...chunk.length) {
                chars.push(chunk.charAt(i));
            }
        }
        chars.shuffle();
        return chars.join('').substr(0, size);

    }

    static var _persistentIds:Map<Int,String> = null;

    /**
     * Return a persistent identifier for this device. The identifier is expected
     * to stay the same as long as the user keeps the app installed.
     * Multiple identifiers can be generated/retrieved by using different slots (default 0).
     * Size of the persistent identifier can be provided, but will only have effect when
     * generating a new identifier.
     */
    public static function persistentId(?slot:Int = 0, ?size:Int = 32):String {

        // Create map if needed
        if (_persistentIds == null) _persistentIds = new Map();

        // Already loaded?
        var id = _persistentIds.get(slot);
        if (id != null) return id;

        // No, check disk
        id = app.backend.io.readString('persistentId_$slot');
        if (id != null) {
            _persistentIds.set(slot, id);
            return id;
        }

        // No id, create a new one
        id = randomId(size);
        if (!app.backend.io.saveString('persistentId_$slot', id)) {
            log.warning('Failed to save persistent id ($id) at slot $slot');
        }
        // Keep id in memory
        _persistentIds.set(slot, id);

        // Return result
        return id;

    }

    public static function resetPersistentId(?slot:Int = 0) {

        if (_persistentIds != null) _persistentIds.remove(slot);
        app.backend.io.saveString('persistentId_$slot', null);

    }

    inline public static function base62Id(?val:Null<Int>):String {

        // http://www.anotherchris.net/csharp/friendly-unique-id-generation-part-2/#base62
        // Haxe snippet from Luxe

        if (val == null) {
            val = Std.int(Math.random() * 0x7ffffffe);
        }

        inline function toChar(value:Int):String {
            if (value > 9) {
                var ascii = (65 + (value - 10));
                if (ascii > 90) { ascii += 6; }
                return String.fromCharCode(ascii);
            } else return Std.string(value).charAt(0);
        }

        var r = Std.int(val % 62);
        var q = Std.int(val / 62);
        if (q > 0) return base62Id(q) + toChar(r);
        else return Std.string(toChar(r));

    }

    public static function println(data:String):Void {

#if web
        var electronRunner:Dynamic = null;
        #if !completion
        #if luxe
        var mainClazz = Type.resolveClass('Main');
        electronRunner = Reflect.field(mainClazz, 'electronRunner');
        #elseif clay
        electronRunner = backend.ElectronRunner.electronRunner;
        #end
        #end
#end

        #if web
        if (electronRunner != null) {
            electronRunner.consoleLog('[error] ' + data);
        } else {
            untyped console.log(''+data);
        }
        #elseif cs
        trace(data);
        #elseif sys
        Sys.println(''+data);
        #else
        trace(data);
        #end

    }

    public static function printStackTrace(returnOnly:Bool = false):String {

        var result = new StringBuf();
#if web
        var electronRunner:Dynamic = null;
#end

        inline function print(data:Dynamic) {
            if (!returnOnly) {
                #if web
                if (electronRunner != null) {
                    electronRunner.consoleLog('[error] ' + data);
                } else {
                    untyped console.log(''+data);
                }
                #elseif cs
                trace(data);
                #elseif sys
                Sys.println(''+data);
                #else
                trace(data);
                #end
            }
            result.add(data);
            result.addChar('\n'.code);
        }

#if web
        var jsError:Dynamic = null;
        untyped js.Syntax.code('
            try {
                throw new Error();
            } catch (e) {
                {0} = e;
            }
        ', jsError);

        var stack = (''+jsError.stack).split("\n");
        var len = stack.length;
        var i = len - 1;
        var file = '';
        var line = 0;
        var isWin:Bool = untyped navigator.platform.indexOf('Win') != -1;

        #if !completion
        #if luxe
        var mainClazz = Type.resolveClass('Main');
        electronRunner = Reflect.field(mainClazz, 'electronRunner');
        #elseif clay
        electronRunner = backend.ElectronRunner.electronRunner;
        #end
        #end

        while (i >= 2) { // Skip first two entries because they point to the thrown error and printStackTrace() call
            var str = stack[i];
            str = str.ltrim();

            if (electronRunner != null) {
                // File in haxe project
                str = str.replace('http://localhost:' + electronRunner.serverPort + '/file:' + (isWin ? '/' : ''), '');

                // File in compiled project
                str = str.replace('http://localhost:' + electronRunner.serverPort + '/', electronRunner.appFiles + '/');
            }

            print(str);

            i--;
        }

#else
        var stack = CallStack.callStack();

        // Reverse stack
        var reverseStack = [].concat(stack);
        reverseStack.reverse();
        reverseStack.pop(); // Remove last element, no need to display it

        // Print stack trace and error
        for (item in reverseStack) {
            print(stackItemToString(item));
        }
#end

        return result.toString();

    }

    static final RE_MODULE_AT = ~/^\s*(?:at\s*)?([^\s]+\.js)(?:\s*:\s*([0-9]+)(?:\s*:\s*([0-9]+))?)?\s*$/;

    public static function stackItemToString(item:StackItem):String {

        #if js
        final sourceMapSupport:Dynamic = js.Syntax.code('window.sourceMapSupport');
        #end

        var str:String = "";
        switch (item) {
            case CFunction:
                str = "a C function";
            case Module(m):
                var matchedModule = false;
                #if js
                if (RE_MODULE_AT.match(m)) {
                    var file = RE_MODULE_AT.matched(1);
                    var line = RE_MODULE_AT.matched(2);
                    var column = RE_MODULE_AT.matched(3);
                    str = file;
                    if (line != null) {
                        str += ':' + line;
                    }
                    matchedModule = true;
                }
                #end
                if (!matchedModule) {
                    str = "module " + m;
                }
            case FilePos(itm,file,line,column):
                #if js
                // Only try to resolve source map if it's not already a Haxe source file
                if (sourceMapSupport != null && !StringTools.endsWith(file, ".hx")) {
                    try {
                        var position = {
                            source: file,
                            line: line,
                            column: column
                        };

                        // Use mapSourcePosition to convert the compiled position to original
                        var originalPos = js.Syntax.code('{0}.mapSourcePosition({1})', sourceMapSupport, position);

                        // Update file and line with the mapped values
                        if (originalPos != null) {
                            file = originalPos.source;
                            line = originalPos.line;
                            column = originalPos.column;
                        }
                    } catch (e:Dynamic) {
                        // Just use the original file and line if mapping fails
                    }
                }
                #end
                if (itm != null) {
                    str = stackItemToString(itm) + " (";
                }
                str += file;
                #if HXCPP_STACK_LINE
                    str += " line ";
                    str += line;
                #end
                if (itm != null) str += ")";
            case Method(cname,meth):
                str += (cname);
                str += (".");
                str += (meth);
            #if (haxe_ver >= "3.1.0")
            case LocalFunction(n):
            #else
            case Lambda(n):
            #end
                str += ("local function #");
                str += (n);
        }

        return str;

    }

    inline public static function radToDeg(rad:Float):Float {
        return rad * 57.29577951308232;
    }

    inline public static function degToRad(deg:Float):Float {
        return deg * 0.017453292519943295;
    }

    inline public static function round(value:Float, decimals:Int = 0):Float {
        return if (decimals > 0) {
            var factor = 1.0;
            while (decimals-- > 0) {
                factor *= 10.0;
            }
            Math.round(value * factor) / factor;
        }
        else {
            Math.round(value);
        }
    }

    /**
     * Java's String.hashCode() method implemented in Haxe.
     * source: https://github.com/rjanicek/janicek-core-haxe/blob/master/src/co/janicek/core/math/HashCore.hx
     */
    inline public static function hashCode(s:String):Int {
        var hash = 0;
        if (s.length == 0) return hash;
        for (i in 0...s.length) {
            hash = ((hash << 5) - hash) + s.charCodeAt(i);
            hash = hash & hash; // Convert to 32bit integer
        }
        return hash;
    }

    /**
     * Generate an uniform list of the requested size,
     * containing values uniformly repartited from frequencies.
     * @param values the values to put in list
     * @param probabilities the corresponding probability for each value
     * @param size the size of the final list
     */
    public static function uniformFrequencyList(values:Array<Int>, frequencies:Array<Float>, size:Int):Array<Int> {

        var list:Array<Int> = [];
        var pickValues:Array<Float> = [];

        for (i in 0...values.length) {
            pickValues[i] = 0;
        }

        // Set initial pick values
        for (i in 0...frequencies.length) {
            pickValues[i] += frequencies[i];
        }

        for (index in 0...size) {
            // Pick a value
            var bestPick = 0;
            var bestPickValue = 0.0;
            for (i in 0...values.length) {
                var pickValue = pickValues[i];
                if (pickValue > bestPickValue) {
                    bestPick = i;
                    bestPickValue = pickValue;
                }
            }

            // Add value
            list.push(values[bestPick]);
            pickValues[bestPick] -= 1.0;

            // Increment pick values
            for (i in 0...frequencies.length) {
                pickValues[i] += frequencies[i];
            }
        }

        return list;

    }

    /**
     * Transforms `SOME_IDENTIFIER` to `SomeIdentifier`
     */
    public static function upperCaseToCamelCase(input:String, firstLetterUppercase:Bool = true):String {

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
                res.add(c.toUpperCase());
            }
            else {
                res.add(c.toLowerCase());
            }

            i++;
        }

        return res.toString();

    }

    /**
     * Transforms `SomeIdentifier`/`someIdentifier`/`some identifier` to `SOME_IDENTIFIER`
     */
    public static function camelCaseToUpperCase(input:String, firstLetterUppercase:Bool = true):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var canAddSpace = false;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '.') {
                res.add('_');
                canAddSpace = false;
            }
            else if (RE_ASCII_CHAR.match(c)) {

                var uc = c.toUpperCase();
                var isUpperCase = (c == uc);

                if (canAddSpace && isUpperCase) {
                    res.add('_');
                    canAddSpace = false;
                }

                res.add(uc);
                canAddSpace = !isUpperCase;
            }
            else {
                res.add('_');
                canAddSpace = false;
            }

            i++;
        }

        var str = res.toString();
        while (str.endsWith('_')) str = str.substr(0, str.length - 1);

        return str;

    }

    inline public static function functionEquals(functionA:Dynamic, functionB:Dynamic):Bool {

        #if (js || cpp)
        return functionA == functionB;
        #else
        return Reflect.compareMethods(functionA, functionB);
        #end

    }

    public static function decodeUriParams(raw:String):Map<String,String> {

        var result = new Map<String,String>();

        var parts = raw.split('&');
        for (part in parts) {
            var equalIndex = part.indexOf('=');
            if (equalIndex != -1) {
                result.set(
                    StringTools.urlDecode(part.substring(0, equalIndex)),
                    StringTools.urlDecode(part.substring(equalIndex + 1))
                );
            }
        }

        return result;

    }

    /**
     * Transforms a value between 0 and 1 to another value between 0 and 1 following a sinusoidal curve
     * @param value a value between 0 and 1. If giving a value > 1, its modulo 1 will be used.
     * @return Float
     */
    public static function sinRatio(value:Float):Float {

        if (value >= 1.0)
            value = value % 1.0;
        return (Math.sin(value * Math.PI * 2) + 1.0) * 0.5;

    }

    /**
     * Transforms a value between 0 and 1 to another value between 0 and 1 following a cosinusoidal curve
     * @param value a value between 0 and 1. If giving a value > 1, its modulo 1 will be used.
     * @return Float
     */
    public static function cosRatio(value:Float):Float {

        if (value >= 1.0)
            value = value % 1.0;
        return (Math.cos(value * Math.PI * 2) + 1.0) * 0.5;

    }

    /**
     * Given an array of keys and an array of matching values, interpolate a new value from interpolatedKey
     * @param keys A list of keys
     * @param values A list of values
     * @param interpolatedKey The interpolated key, used to find a matching interpolated value
     * @return Interpolated value
     */
    public static function valueFromInterpolatedKey(keys:Array<Float>, values:Array<Float>, interpolatedKey:Float):Float {

        final len = keys.length;
        final lenMinus1 = len - 1;

        assert(len > 0, 'Keys array must not be empty');
        assert(values.length >= len, 'Values array must be of equal or higher size of keys array');

        var value:Float = 0.0;

        if (interpolatedKey < keys.unsafeGet(0)) {
            value = values.unsafeGet(0);
        }
        else if (interpolatedKey >= keys.unsafeGet(lenMinus1)) {
            value = values.unsafeGet(lenMinus1);
        }
        else {
            var i = 0;
            var iPlus1 = 1;
            while (interpolatedKey > keys.unsafeGet(iPlus1)) {
                i++;
                iPlus1++;
            }
            final ratio = (interpolatedKey - keys.unsafeGet(i)) / (keys.unsafeGet(iPlus1) - keys.unsafeGet(i));
            value = values.unsafeGet(i) + (values.unsafeGet(iPlus1) - values.unsafeGet(i)) * ratio;
        }

        return value;

    }

    /**
     * Given an array of X and Y values, interpolate a new Y value from interpolated X
     * @param points A list of X and Y values
     * @param interpolatedX The interpolated X key, used to find a matching interpolated Y
     * @return Interpolated Y value
     */
    public static function yFromInterpolatedX(points:Array<Float>, interpolatedX:Float):Float {

        final len:Int = points.length;
        final lenMinus1:Int = len - 2;

        assert(len > 1, 'Points array must not be empty');

        var y:Float = 0.0;

        if (interpolatedX < points.unsafeGet(0)) {
            y = points.unsafeGet(1);
        }
        else if (interpolatedX >= points.unsafeGet(lenMinus1)) {
            final lenMinus1Val = lenMinus1 + 1;
            y = points.unsafeGet(lenMinus1Val);
        }
        else {
            var i = 0;
            var iPlus1 = 2;
            while (interpolatedX > points.unsafeGet(iPlus1)) {
                i += 2;
                iPlus1 += 2;
            }
            final ratio = (interpolatedX - points.unsafeGet(i)) / (points.unsafeGet(iPlus1) - points.unsafeGet(i));
            final iVal = i + 1;
            final iPlus1Val = iPlus1 + 1;
            y = points.unsafeGet(iVal) + (points.unsafeGet(iPlus1Val) - points.unsafeGet(iVal)) * ratio;
        }

        return y;

    }

    public static function command(cmd:String, ?args:Array<String>, ?options:{ ?cwd: String, ?detached: Bool }, result:(code:Int, out:String, err:String)->Void):Void {

        if (args == null)
            args = [];

        #if (cs || sys || node || nodejs || hxnodejs)

        var prevCwd = null;
        var detached = false;
        if (options != null) {
            if (options.cwd != null) {
                prevCwd = Sys.getCwd();
                Sys.setCwd(options.cwd);
            }
            if (options.detached == true) {
                detached = true;
            }
        }
        var proc = new sys.io.Process(cmd, args, detached);
        var out = proc.stdout.readAll().toString();
        var err = proc.stderr.readAll().toString();
        var exitCode = proc.exitCode(true);
        proc.close();

        if (prevCwd != null) {
            Sys.setCwd(prevCwd);
        }

        result(exitCode, out, err);

        #elseif (web && ceramic_use_electron)

        var childProcess = Platform.nodeRequire('child_process');
        var opt:Dynamic = {};
        var detached = false;
        if (options != null) {
            if (options.cwd != null) {
                opt.cwd = options.cwd;
            }
            if (options.detached == true) {
                detached = true;
            }
        }

        var proc:Dynamic = null;
        proc = childProcess.execFile(cmd, args, opt, function(err:Dynamic, stdout:Dynamic, stderr:Dynamic) {

            if (result != null) {
                var _done = result;
                result = null;
                _done(proc.exitCode, Std.string(stdout != null ? stdout : ''), Std.string(stderr != null ? stderr : ''));
            }

        });

        if (detached)
            proc.unref();

        #else

        // Not implemented
        result(-1, null, null);

        #end

    }

    public static function replaceIdentifier(str:String, word:String, replacement:String):String {

        str = str.replace('\n', ' \n ');
        str = str.replace('\r', ' \r ');
        str = ' ' + str + ' ';

        var delimiter = '(\\s|[^a-zA-Z0-9_])';
        str = new EReg(delimiter + EReg.escape(word) + delimiter, 'g').replace(str, "$1" + replacement.replace("$", "$$") + "$2");

        str = str.substring(1, str.length - 1);
        str = str.replace(' \r ', '\r');
        str = str.replace(' \n ', '\n');

        return str;

    }

    public static function imageTypeFromBytes(bytes:Bytes):ImageType {

        if (
            bytes.get(0) == 0xFF &&
            bytes.get(1) == 0xD8 &&
            bytes.get(2) == 0xFF) {

            return ImageType.JPEG;
        }
        else if (
            bytes.get(0) == 0x89 &&
            bytes.get(1) == 0x50 &&
            bytes.get(2) == 0x4E &&
            bytes.get(3) == 0x47 &&
            bytes.get(4) == 0x0D &&
            bytes.get(5) == 0x0A &&
            bytes.get(6) == 0x1A &&
            bytes.get(7) == 0x0A) {

            return ImageType.PNG;
        }

        return null;

    }

    public inline static function lerp(a:Float, b:Float, t:Float):Float {
        return a + (b - a) * t;
    }

    /**
     * Returns `true` if the current platform is iOS, which is the case
     * when we are running a native iOS app or when we are running
     * on web from an iOS mobile browser.
     */
    #if ceramic_fake_ios
    public static function isIos():Bool {
        return true;
    }
    #elseif web
    public static function isIos():Bool {
        static var result:Int = -1;
        if (result == -1) {
            result = 0;
            final ua = js.Browser.navigator != null ? js.Browser.navigator.userAgent : '';
            final notMSStream:Bool = js.Syntax.code('!window.MSStream');
            if (notMSStream && (ua.indexOf('iPhone') != -1 || ua.indexOf('iPad') != -1 || ua.indexOf('iPod') != -1)) {
                result = 1;
            }
        }
        return result != 0;
    }
    #elseif ios
    public static function isIos():Bool {
        return true;
    }
    #elseif (cs && unity)
    public static function isIos():Bool {
        return untyped __cs__('UnityEngine.Application.platform == UnityEngine.RuntimePlatform.IPhonePlayer');
    }
    #else
    public static function isIos():Bool {
        return false;
    }
    #end

    /**
     * Returns `true` if the current platform is Android, which is the case
     * when we are running a native Android app or when we are running
     * on web from an Android mobile browser.
     */
    #if ceramic_fake_android
    public static function isAndroid():Bool {
        return true;
    }
    #elseif web
    public static function isAndroid():Bool {
        static var result:Int = -1;
        if (result == -1) {
            result = 0;
            final ua = js.Browser.navigator != null ? js.Browser.navigator.userAgent : '';
            if (ua.toLowerCase().indexOf('android') != -1) {
                result = 1;
            }
        }
        return result != 0;
    }
    #elseif android
    public static function isAndroid():Bool {
        return true;
    }
    #elseif (cs && unity)
    public static function isAndroid():Bool {
        return untyped __cs__('UnityEngine.Application.platform == UnityEngine.RuntimePlatform.Android');
    }
    #else
    public static function isAndroid():Bool {
        return false;
    }
    #end

    /**
     * Returns `1` if the value is above or equal to zero, `-1` otherwise
     */
    inline public static function sign(value:Float):Float {
        return value >= 0 ? 1 : -1;
    }

}

package ceramic;

import ceramic.PlatformSpecific;
import haxe.rtti.CType;
import haxe.CallStack;
import ceramic.Shortcuts.*;

using StringTools;
using ceramic.Extensions;

/** Various utilities. Some of them are used by ceramic itself or its backends. */
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

        return PlatformSpecific.getRtti(c);

    }

    static var _nextUniqueIntCursor:Int = 0;
    static var _nextUniqueInt0:Int = Std.int(Math.random() * 0x7ffffffe);
    static var _nextUniqueInt1:Int = Std.int(Date.now().getTime() * 0.0001);
    static var _nextUniqueInt2:Int = Std.int(Math.random() * 0x7ffffffe);
    static var _nextUniqueInt3:Int = Std.int(Math.random() * 0x7ffffffe);

    /** Provides an identifier which is garanteed to be unique on this local device.
        It however doesn't garantee that this identifier is not predictable. */
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

    }

    /** Provides a random identifier which should be fairly unpredictable and
        should have an extremely low chance to provide the same identifier twice. */
    public static function randomId(?size:Int = 32):String {

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

    /** Return a persistent identifier for this device. The identifier is expected
        to stay the same as long as the user keeps the app installed.
        Multiple identifiers can be generated/retrieved by using different slots (default 0).
        Size of the persistent identifier can be provided, but will only have effect when
        generating a new identifier. */
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

    public static function printStackTrace():String {

        var result = new StringBuf();
#if web
        var electronRunner:Dynamic = null;
#end

        inline function print(data:Dynamic) {
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

        #if (luxe && !completion)
        var mainClazz = Type.resolveClass('Main');
        electronRunner = Reflect.field(mainClazz, 'electronRunner');
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

    public static function stackItemToString(item:StackItem):String {

        var str:String = "";
        switch (item) {
            case CFunction:
                str = "a C function";
            case Module(m):
                str = "module " + m;
            case FilePos(itm,file,line):
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

    /** Clamp an degrees (angle) value between 0 (included) and 360 (excluded) */
    inline public static function clampDegrees(deg:Float):Float {

        // Clamp between 0-360
        while (deg < 0) {
            deg += 360;
        }
        while (deg >= 360) {
            deg -= 360;
        }

        return deg;

    }

    inline public static function distance(x1:Float, y1:Float, x2:Float, y2:Float):Float {

        var dx:Float = x2 - x1;
        var dy:Float = y2 - y1;

        return Math.sqrt(dx * dx + dy * dy);

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

    /** Generate an uniform list of the requested size,
        containing values uniformly repartited from frequencies.
        @param values the values to put in list
        @param probabilities the corresponding probability for each value
        @param size the size of the final list */
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

    /** Transforms `SOME_IDENTIFIER` to `SomeIdentifier` */
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

    /** Transforms `SomeIdentifier`/`someIdentifier`/`some identifier` to `SOME_IDENTIFIER` */
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

}

package ceramic;

import ceramic.internal.PlatformSpecific;
import haxe.rtti.CType;
import haxe.CallStack;
import ceramic.Shortcuts.*;

using StringTools;
using ceramic.Extensions;

/** Various utilities. Some of them are used by ceramic itself or its backends. */
class Utils {

    public static function realPath(path:String):String {

        path = ceramic.Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            ceramic.Path.join([ceramic.App.app.settings.assetsPath, path]);

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

    } //uniqueId

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

    } //randomId

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
            warning('Failed to save persistent id at slot $slot');
        }
        // Keep id in memory
        _persistentIds.set(slot, id);

        // Return result
        return id;

    } //persistentId

    public static function resetPersistentId(?slot:Int = 0) {

        if (_persistentIds != null) _persistentIds.remove(slot);
        app.backend.io.saveString('persistentId_$slot', null);

    } //resetPersistentId

    inline public static function base62Id(?val:Null<Int>):String {

        // http://www.anotherchris.net/csharp/friendly-unique-id-generation-part-2/#base62
        // Haxe snippet from Luxe

        if (val == null) {
            val = Std.random(0x7fffffff);
        }

        inline function toChar(value:Int):String {
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
            #elseif sys
            Sys.println(''+data);
            #else
            trace(data);
            #end
        }

#if web
        var jsError:Dynamic = null;
        untyped __js__('
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
        electronRunner = @:privateAccess Main.electronRunner;
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

    } //printStackTrace

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

    } //stackItemToString

} //Utils

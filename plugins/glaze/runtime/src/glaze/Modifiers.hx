// Ported from gpui-pre 0.3.10: src/platform/keystroke.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The state of the modifier keys at some point in time.
 *
 * Rust's `Copy` struct of five booleans becomes an immutable bit set: values
 * compare with `==`, never allocate, and `withX()` returns a modified copy.
 *
 * `function` is a Haxe keyword: the function key is the `function_` property.
 * Static constructors cannot share a name with a property, so `control()`,
 * `alt()`, `shift()` and `function()` are `controlKey()`, `altKey()`,
 * `shiftKey()` and `functionKey()` (like GPUI's own `super_key()`).
 */
abstract Modifiers(Int) {

    static inline final CONTROL = 1;

    static inline final ALT = 2;

    static inline final SHIFT = 4;

    static inline final PLATFORM = 8;

    static inline final FUNCTION = 16;

    inline function new(bits:Int) {
        this = bits;
    }

    /**
     * Builds modifiers from flags (Rust: struct literal, missing fields `false`).
     */
    public static inline function of(control:Bool = false, alt:Bool = false, shift:Bool = false, platform:Bool = false, function_:Bool = false):Modifiers {
        return new Modifiers(
            (control ? CONTROL : 0) | (alt ? ALT : 0) | (shift ? SHIFT : 0) | (platform ? PLATFORM : 0) | (function_ ? FUNCTION : 0)
        );
    }

    /**
     * The control key.
     */
    public var control(get, never):Bool;
    inline function get_control():Bool return (this & CONTROL) != 0;

    /**
     * The alt key. Sometimes also known as the 'meta' key.
     */
    public var alt(get, never):Bool;
    inline function get_alt():Bool return (this & ALT) != 0;

    /**
     * The shift key.
     */
    public var shift(get, never):Bool;
    inline function get_shift():Bool return (this & SHIFT) != 0;

    /**
     * The command key on macOS, the windows key on Windows, the super key on Linux.
     */
    public var platform(get, never):Bool;
    inline function get_platform():Bool return (this & PLATFORM) != 0;

    /**
     * The function key (Rust: `function`, a Haxe keyword).
     */
    public var function_(get, never):Bool;
    inline function get_function_():Bool return (this & FUNCTION) != 0;

    inline function with(bit:Int, value:Bool):Modifiers {
        return new Modifiers(value ? (this | bit) : (this & ~bit));
    }

    public inline function withControl(value:Bool):Modifiers return with(CONTROL, value);

    public inline function withAlt(value:Bool):Modifiers return with(ALT, value);

    public inline function withShift(value:Bool):Modifiers return with(SHIFT, value);

    public inline function withPlatform(value:Bool):Modifiers return with(PLATFORM, value);

    public inline function withFunction(value:Bool):Modifiers return with(FUNCTION, value);

    /**
     * Returns whether any modifier key is pressed.
     */
    public inline function modified():Bool {
        return this != 0;
    }

    /**
     * Whether the semantically 'secondary' modifier key is pressed: command on
     * macOS, control on Linux and Windows. GPUI takes `cx` to read the host OS.
     */
    public function secondary(?os:OperatingSystem):Bool {
        if (os == null) os = OperatingSystem.current;
        return os.isMac() ? platform : control;
    }

    /**
     * Returns how many modifier keys are pressed.
     */
    public function numberOfModifiers():Int {
        return (control ? 1 : 0) + (alt ? 1 : 0) + (shift ? 1 : 0) + (platform ? 1 : 0) + (function_ ? 1 : 0);
    }

    /**
     * Returns `Modifiers` with no modifiers.
     */
    public static inline function none():Modifiers return new Modifiers(0);

    /**
     * Returns `Modifiers` with just the command key.
     */
    public static inline function command():Modifiers return new Modifiers(PLATFORM);

    /**
     * Returns `Modifiers` with just the secondary key pressed (command on macOS,
     * control elsewhere).
     */
    public static function secondaryKey(?os:OperatingSystem):Modifiers {
        if (os == null) os = OperatingSystem.current;
        return os.isMac() ? new Modifiers(PLATFORM) : new Modifiers(CONTROL);
    }

    /**
     * Returns `Modifiers` with just the windows key.
     */
    public static inline function windows():Modifiers return new Modifiers(PLATFORM);

    /**
     * Returns `Modifiers` with just the super key.
     */
    public static inline function superKey():Modifiers return new Modifiers(PLATFORM);

    /**
     * Returns `Modifiers` with just control.
     */
    public static inline function controlKey():Modifiers return new Modifiers(CONTROL);

    /**
     * Returns `Modifiers` with just alt.
     */
    public static inline function altKey():Modifiers return new Modifiers(ALT);

    /**
     * Returns `Modifiers` with just shift.
     */
    public static inline function shiftKey():Modifiers return new Modifiers(SHIFT);

    /**
     * Returns `Modifiers` with just function.
     */
    public static inline function functionKey():Modifiers return new Modifiers(FUNCTION);

    /**
     * Returns `Modifiers` with command + shift.
     */
    public static inline function commandShift():Modifiers return new Modifiers(SHIFT | PLATFORM);

    /**
     * Returns `Modifiers` with control + shift.
     */
    public static inline function controlShift():Modifiers return new Modifiers(SHIFT | CONTROL);

    /**
     * Checks if this `Modifiers` is a subset of another `Modifiers`.
     */
    public inline function isSubsetOf(other:Modifiers):Bool {
        return (other.toInt() & this) == this;
    }

    /**
     * The raw bits (control 1, alt 2, shift 4, platform 8, function 16).
     */
    public inline function toInt():Int {
        return this;
    }

    @:op(A | B) inline function or(other:Modifiers):Modifiers return new Modifiers(this | other.toInt());

    @:op(A & B) inline function and(other:Modifiers):Modifiers return new Modifiers(this & other.toInt());

    @:op(A ^ B) inline function xor(other:Modifiers):Modifiers return new Modifiers(this ^ other.toInt());

    @:op(A == B) static inline function eq(a:Modifiers, b:Modifiers):Bool return a.toInt() == b.toInt();

    @:op(A != B) static inline function neq(a:Modifiers, b:Modifiers):Bool return a.toInt() != b.toInt();

    public function toString():String {
        return 'Modifiers(control: $control, alt: $alt, shift: $shift, platform: $platform, function: $function_)';
    }

}

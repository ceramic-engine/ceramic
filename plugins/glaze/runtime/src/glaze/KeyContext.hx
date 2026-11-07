// Ported from gpui-pre 0.3.10: src/keymap/context.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A datastructure for resolving whether an action should be dispatched at this
 * point in the element tree. Contains a set of identifiers and/or key value
 * pairs representing the current context for the keymap.
 */
class KeyContext {

    final entries:Array<ContextEntry>;

    /**
     * An empty context (Rust: `KeyContext::default()`).
     */
    public function new() {
        entries = [];
    }

    /**
     * Initializes a key context with the supplied host operating system.
     */
    public static function newWithDefaults(os:OperatingSystem):KeyContext {
        final context = new KeyContext();
        context.set('os', switch os {
            case Mac: 'macos';
            case Linux | FreeBsd: 'linux';
            case Windows: 'windows';
            case Ios: 'ios';
            case Android: 'android';
            case Unknown: 'unknown';
        });
        return context;
    }

    /**
     * Returns the primary context entry (usually the name of the component).
     */
    public function primary():Null<ContextEntry> {
        for (entry in entries) {
            if (entry.value == null) return entry;
        }
        return null;
    }

    /**
     * Returns everything except the primary context entry.
     */
    public function secondary():Array<ContextEntry> {
        final primary = this.primary();
        return [for (entry in entries) if (primary == null || !entry.equals(primary)) entry];
    }

    /**
     * The entries of this context, in insertion order.
     */
    public function iterator():Iterator<ContextEntry> {
        return entries.iterator();
    }

    /**
     * Parse a key context from a string. The key context format is very simple:
     * - either a single identifier, such as `StatusBar`
     * - or a key value pair, such as `mode = visible`
     * - separated by whitespace, such as `StatusBar mode = visible`
     *
     * Rust returns `Result`; this never fails in practice (unknown characters
     * produce empty identifiers, like GPUI).
     */
    public static function parse(source:String):KeyContext {
        final context = new KeyContext();
        final pos = ContextScanner.skipWhitespace(source, 0);
        parseExpr(source, pos, context);
        return context;
    }

    static function parseExpr(source:String, pos:Int, context:KeyContext):Void {
        // Rust recurses once per entry; a loop gives the same result without
        // the risk of a stack overflow.
        while (pos < source.length) {
            final keyEnd = ContextScanner.takeIdentifier(source, pos);
            final key = source.substring(pos, keyEnd);
            pos = ContextScanner.skipWhitespace(source, keyEnd);
            if (pos < source.length && StringTools.fastCodeAt(source, pos) == '='.code) {
                pos = ContextScanner.skipWhitespace(source, pos + 1);
                final valueEnd = ContextScanner.takeIdentifier(source, pos);
                final value = source.substring(pos, valueEnd);
                pos = ContextScanner.skipWhitespace(source, valueEnd);
                context.set(key, value);
            }
            else {
                context.add(key);
            }
            if (keyEnd == pos && key.length == 0) {
                // Rust would recurse forever on a character that is neither an
                // identifier, `=` nor whitespace (stack overflow). Stop instead.
                break;
            }
        }
    }

    /**
     * Check if this context is empty.
     */
    public function isEmpty():Bool {
        return entries.length == 0;
    }

    /**
     * Clear this context.
     */
    public function clear():Void {
        entries.resize(0);
    }

    /**
     * Extend this context with another context.
     */
    public function extend(other:KeyContext):Void {
        for (entry in other.entries) {
            if (!contains(entry.key)) {
                entries.push(entry);
            }
        }
    }

    /**
     * Add an identifier to this context, if it's not already in this context.
     */
    public function add(identifier:String):Void {
        if (!contains(identifier)) {
            entries.push(new ContextEntry(identifier, null));
        }
    }

    /**
     * Set a key value pair in this context, if it's not already set.
     */
    public function set(key:String, value:String):Void {
        if (!contains(key)) {
            entries.push(new ContextEntry(key, value));
        }
    }

    /**
     * Check if this context contains a given identifier or key.
     */
    public function contains(key:String):Bool {
        for (entry in entries) {
            if (entry.key == key) return true;
        }
        return false;
    }

    /**
     * Get the associated value for a given identifier or key.
     */
    public function get(key:String):Null<String> {
        for (entry in entries) {
            if (entry.key == key) return entry.value;
        }
        return null;
    }

    public function copy():KeyContext {
        final result = new KeyContext();
        for (entry in entries) result.entries.push(entry);
        return result;
    }

    /**
     * Structural equality (Rust derived `PartialEq`: same entries, same order).
     */
    public function equals(other:KeyContext):Bool {
        if (other == null || other.entries.length != entries.length) return false;
        for (i in 0...entries.length) {
            if (!entries[i].equals(other.entries[i])) return false;
        }
        return true;
    }

    /**
     * Rust `Debug` format: `key` or `key=value`, separated by spaces.
     */
    public function toString():String {
        return [for (entry in entries) entry.value != null ? entry.key + '=' + entry.value : entry.key].join(' ');
    }

}

/**
 * An entry in a KeyContext.
 */
class ContextEntry {

    /**
     * The key (or name if no value).
     */
    public final key:String;

    /**
     * The value.
     */
    public final value:Null<String>;

    public function new(key:String, value:Null<String>) {
        this.key = key;
        this.value = value;
    }

    public function equals(other:ContextEntry):Bool {
        return other != null && key == other.key && value == other.value;
    }

    public function toString():String {
        return value != null ? key + '=' + value : key;
    }

}

/**
 * Character classes shared by the key context and predicate parsers.
 *
 * Rust works on `char` (Unicode scalar values) with `char::is_alphanumeric`
 * and `char::is_whitespace`. Here, ASCII is classified exactly, Unicode white
 * space is recognized, and any other non-ASCII code unit counts as
 * alphanumeric (context names are ASCII in practice).
 */
class ContextScanner {

    public static function isWhitespace(c:Int):Bool {
        return c == ' '.code || (c >= 0x09 && c <= 0x0D) || c == 0x85 || c == 0xA0 || c == 0x1680
            || (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F
            || c == 0x205F || c == 0x3000;
    }

    public static function isAlphanumeric(c:Int):Bool {
        if (c < 128) {
            return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code);
        }
        return !isWhitespace(c);
    }

    public static inline function isIdentifierChar(c:Int):Bool {
        return isAlphanumeric(c) || c == '_'.code || c == '-'.code;
    }

    public static inline function isVimOperatorChar(c:Int):Bool {
        return c == '>'.code || c == '<'.code || c == '~'.code || c == '"'.code || c == '?'.code;
    }

    /**
     * Returns the position of the first non white space character at or after `pos`.
     */
    public static function skipWhitespace(source:String, pos:Int):Int {
        while (pos < source.length && isWhitespace(StringTools.fastCodeAt(source, pos))) {
            pos++;
        }
        return pos;
    }

    /**
     * Returns the end of the identifier starting at `pos`.
     */
    public static function takeIdentifier(source:String, pos:Int):Int {
        while (pos < source.length && isIdentifierChar(StringTools.fastCodeAt(source, pos))) {
            pos++;
        }
        return pos;
    }

}

// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A clipboard item that should be copied to the clipboard
 * (`cx.writeToClipboard(item)`, `cx.readFromClipboard()`).
 */
class ClipboardItem {

    /** The entries in this clipboard item. */
    public final entries:Array<ClipboardEntry>;

    public function new(entries:Array<ClipboardEntry>) {
        this.entries = entries;
    }

    /** Create a new string item with no associated metadata */
    public static function newString(text:String):ClipboardItem {
        return new ClipboardItem([ClipboardEntry.String(new ClipboardString(text))]);
    }

    /** Create a new string item with the given text and associated metadata */
    public static function newStringWithMetadata(text:String, metadata:String):ClipboardItem {
        return new ClipboardItem([ClipboardEntry.String(new ClipboardString(text, metadata))]);
    }

    /** Create a new string item with the given text and metadata serialized as JSON */
    public static function newStringWithJsonMetadata(text:String, metadata:Dynamic):ClipboardItem {
        return new ClipboardItem([ClipboardEntry.String(new ClipboardString(text).withJsonMetadata(metadata))]);
    }

    /** Create a new image item with no associated metadata */
    public static function newImage(image:Image):ClipboardItem {
        return new ClipboardItem([ClipboardEntry.Image(image)]);
    }

    /**
     * Concatenates together all the string entries in the item.
     * Returns `null` if there were no string entries (or only empty ones).
     */
    public function text():Null<String> {
        final buf = new StringBuf();
        var empty = true;
        for (entry in entries) {
            switch entry {
                case String(string):
                    if (string.text.length > 0) {
                        buf.add(string.text);
                        empty = false;
                    }
                case _:
            }
        }
        return empty ? null : buf.toString();
    }

    /** If this item is one string entry, returns its metadata. */
    public function metadata():Null<String> {
        if (entries.length == 1) {
            switch entries[0] {
                case String(string):
                    return string.metadata;
                case _:
            }
        }
        return null;
    }

    public function equals(other:Null<ClipboardItem>):Bool {
        if (other == null || other.entries.length != entries.length)
            return false;
        for (i in 0...entries.length) {
            final same = switch [entries[i], other.entries[i]] {
                case [String(a), String(b)]: a.equals(b);
                case [Image(a), Image(b)]: a == b;
                case _: false;
            }
            if (!same)
                return false;
        }
        return true;
    }

}

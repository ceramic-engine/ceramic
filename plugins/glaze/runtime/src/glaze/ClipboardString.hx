// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A string entry of a clipboard item, with optional metadata (usually JSON).
 */
class ClipboardString {

    /** The text content. */
    public final text:String;

    /** Optional metadata associated with this clipboard string. */
    public final metadata:Null<String>;

    public function new(text:String, ?metadata:String) {
        this.text = text;
        this.metadata = metadata;
    }

    /**
     * Return a new clipboard string with the metadata replaced by the given value,
     * serialized as JSON.
     */
    public function withJsonMetadata(metadata:Dynamic):ClipboardString {
        return new ClipboardString(text, haxe.Json.stringify(metadata));
    }

    /** The metadata parsed as JSON, or `null` if there is none or it is invalid. */
    public function metadataJson():Dynamic {
        if (metadata == null)
            return null;
        try {
            return haxe.Json.parse(metadata);
        }
        catch (e:Dynamic) {
            return null;
        }
    }

    public function equals(other:Null<ClipboardString>):Bool {
        return other != null && text == other.text && metadata == other.metadata;
    }

}

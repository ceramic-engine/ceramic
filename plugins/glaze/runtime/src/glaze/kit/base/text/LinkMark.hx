// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

/**
 * A link on a run of text.
 */
class LinkMark {

    public var url:String;

    /** Optional identifier for footnotes. */
    public var identifier:Null<String>;

    public var title:Null<String>;

    public function new(url:String = '', ?identifier:String, ?title:String) {
        this.url = url;
        this.identifier = identifier;
        this.title = title;
    }

    public function clone():LinkMark {
        return new LinkMark(url, identifier, title);
    }

    public function equals(other:Null<LinkMark>):Bool {
        return other != null && other.url == url && other.identifier == identifier && other.title == title;
    }

    /** `Option<LinkMark>` equality. */
    public static function eq(a:Null<LinkMark>, b:Null<LinkMark>):Bool {
        return a == null ? b == null : a.equals(b);
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.DefiniteLength;
import glaze.Image;
import glaze.ImageSource;

using glaze.DefiniteLengthTools;

/**
 * An image in the document.
 */
class ImageNode {

    public var url:String = '';
    public var link:Null<LinkMark> = null;
    public var title:Null<String> = null;
    public var alt:Null<String> = null;
    public var width:Null<DefiniteLength> = null;
    public var height:Null<DefiniteLength> = null;

    @:allow(glaze.kit.base.text)
    var span:Null<Span> = null;

    /**
     * The image a `data:` URL carries, decoded on first render and kept for
     * the node's lifetime so it is not decoded again every frame.
     */
    var embeddedInit:Bool = false;
    var embedded:Null<Image> = null;

    public function new(url:String = '') {
        this.url = url;
    }

    public function clone():ImageNode {
        final node = new ImageNode(url);
        node.link = link != null ? link.clone() : null;
        node.title = title;
        node.alt = alt;
        node.width = width;
        node.height = height;
        node.span = span != null ? span.copy() : null;
        node.embeddedInit = embeddedInit;
        node.embedded = embedded;
        return node;
    }

    public function getTitle():String {
        return title != null ? title : (alt != null ? alt : '');
    }

    /**
     * The `ImageSource` to render, without granting implicit filesystem
     * access.
     *
     * A `data:` URL carries its image inline, so it is decoded here rather
     * than handed to GPUI's resource loader, which only fetches over HTTP.
     * Every other document-provided value remains URI-backed, including
     * `file://` and scheme-less strings.
     */
    @:allow(glaze.kit.base.text)
    function source():ImageSource {
        if (!embeddedInit) {
            embeddedInit = true;
            embedded = TextUtils.dataUrlImage(url);
        }
        if (embedded != null)
            return ImageSource.Image(embedded);
        return ImageSource.Resource(glaze.Resource.Uri(url));
    }

    public function equals(other:Null<ImageNode>):Bool {
        inline function lengthEq(a:Null<DefiniteLength>, b:Null<DefiniteLength>):Bool {
            return a == null ? b == null : b != null && a.equals(b);
        }
        return other != null && url == other.url && LinkMark.eq(link, other.link) && title == other.title && alt == other.alt
            && lengthEq(width, other.width) && lengthEq(height, other.height) && Span.eq(span, other.span);
    }

    /** `Option<ImageNode>` equality. */
    public static function eq(a:Null<ImageNode>, b:Null<ImageNode>):Bool {
        return a == null ? b == null : a.equals(b);
    }

}

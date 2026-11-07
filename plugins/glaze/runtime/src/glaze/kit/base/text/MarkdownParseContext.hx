// Ported from gpui-kit 0.8.1: crates/base/src/text/markdown_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import markdown.mdast.Node;

using markdown.mdast.NodeTools;

/**
 * Context passed to custom Markdown parsers.
 */
class MarkdownParseContext {

    final source_:String;
    final offset_:Int;

    @:allow(glaze.kit.base.text)
    function new(source:String, offset:Int) {
        this.source_ = source;
        this.offset_ = offset;
    }

    /** Source text for the Markdown fragment currently being parsed. */
    public inline function source():String {
        return source_;
    }

    /**
     * Byte offset of `source` in the full document when parsing an appended
     * fragment.
     */
    public inline function offset():Int {
        return offset_;
    }

    /** Source slice for a specific mdast node (UTF-8 byte positions). */
    public function nodeSource(node:Node):Null<String> {
        final position = node.position();
        if (position == null)
            return null;
        return TextUtils.byteSlice(source_, position.start.offset, position.end.offset);
    }

}

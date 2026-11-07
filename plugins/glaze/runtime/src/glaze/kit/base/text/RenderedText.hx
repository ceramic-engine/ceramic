// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;
import gpui.util.Utf8;

/**
 * A snapshot of the text a `TextViewState` renders, as of one parse of its
 * content.
 *
 * Offsets into it are UTF-8 byte offsets. It is the string plain copy
 * produces: `hello **world**` renders as `hello world`, escapes are
 * resolved, and heading markers and list markers are left out. Blocks end
 * with a newline and table cells are joined with a space; those separators
 * belong to no block, so no highlight paints them.
 *
 * Two snapshots are equal (`equals`) when they come from the same view and
 * the same parse. The text itself is only built when it is first read.
 */
class RenderedText {

    final owner:Int;

    final revision:Int;

    final document:ParsedDocument;

    final indexCell:RenderedIndexCell;

    /** The text of `document`, whose index `indexCell` holds once built. */
    @:allow(gpui.base.text)
    function new(owner:Int, revision:Int, document:ParsedDocument, indexCell:RenderedIndexCell) {
        this.owner = owner;
        this.revision = revision;
        this.document = document;
        this.indexCell = indexCell;
    }

    /** The rendered text. */
    public function asStr():String {
        return index().text;
    }

    /** The length of the rendered text, in bytes. */
    public function len():Int {
        return index().textLen;
    }

    /** Whether the view renders no text. */
    public function isEmpty():Bool {
        return index().textLen == 0;
    }

    /**
     * The source this text was rendered from, whose byte ranges
     * `rangeForSource` takes.
     */
    public function source():String {
        return document.source;
    }

    /**
     * The range of this text rendered from `source`, a UTF-8 byte range of
     * `source()`.
     *
     * A character is rendered from `source` when any of the source it was
     * rendered from lies in it. Source that renders nothing, such as emphasis
     * delimiters, heading and list markers, code fences, table pipes and link
     * destinations, adds nothing, so `**bold**` and `bold` give the same
     * range. The result is the smallest range holding every character
     * rendered from `source`.
     *
     * Returns `null` when `source` is empty, reversed, out of bounds, or not
     * on a character boundary, or when nothing is rendered from it. HTML views
     * record no source positions, so they always return `null`.
     */
    public function rangeForSource(source:Range):Null<Range> {
        final text = this.source();
        if (source.start >= source.end
            || source.end > Utf8.byteLength(text)
            || !Utf8.isCharBoundary(text, source.start)
            || !Utf8.isCharBoundary(text, source.end)) {
            return null;
        }
        return index().rangeForSource(source);
    }

    @:allow(gpui.base.text)
    function index():RenderedIndex {
        if (indexCell.value == null) {
            indexCell.value = new RenderedIndex(document);
        }
        return indexCell.value;
    }

    public function equals(other:Null<RenderedText>):Bool {
        return other != null && owner == other.owner && revision == other.revision;
    }

    public function toString():String {
        return 'RenderedText { owner: $owner, revision: $revision, .. }';
    }

}

/** Rust `Arc<OnceLock<RenderedIndex>>`: the index, built when first read, shared by snapshots. */
class RenderedIndexCell {

    public var value:Null<RenderedIndex> = null;

    public function new() {}

}

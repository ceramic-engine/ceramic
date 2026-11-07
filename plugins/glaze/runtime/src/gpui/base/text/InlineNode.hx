// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;

/**
 * Shared flag (Rust `Arc<Mutex<bool>>`), kept by the clones of a node.
 */
class SharedFlag {

    public var value:Bool = false;

    public function new() {}

}

/**
 * One run of inline content in a `Paragraph`: marked text, an image or a
 * custom inline node.
 *
 * Rust clones share the selection state (`Arc`): `clone()` keeps the same
 * `state` and `customSelection` instances.
 */
class InlineNode {

    /** The text content. */
    @:allow(gpui.base.text)
    var text_:String;

    @:allow(gpui.base.text)
    var image:Null<ImageNode> = null;

    @:allow(gpui.base.text)
    var custom:Null<MarkdownNode> = null;

    @:allow(gpui.base.text)
    var customSelection:SharedFlag;

    /** The text styles, each the range of the text and the style. */
    @:allow(gpui.base.text)
    var marks_:Array<RangedMark> = [];

    /** Rendered UTF-8 byte spans paired with their exact Markdown source spans. */
    @:allow(gpui.base.text)
    var sourceSegments_:Array<SourceSegment> = [];

    @:allow(gpui.base.text)
    var state:InlineState;

    /** A run of text with no marks. */
    public function new(text:String = '') {
        this.text_ = text;
        this.customSelection = new SharedFlag();
        this.state = new InlineState();
    }

    /** A custom inline node, an atomic object in the flow. */
    public static function ofCustom(node:MarkdownNode):InlineNode {
        final result = new InlineNode(node.asText());
        result.custom = node;
        return result;
    }

    /** An inline image, an atomic object in the flow. */
    public static function ofImage(image:ImageNode):InlineNode {
        final result = new InlineNode('');
        result.image = image;
        return result;
    }

    public function clone():InlineNode {
        final node = new InlineNode(text_);
        node.image = image != null ? image.clone() : null;
        node.custom = custom != null ? custom.clone() : null;
        node.customSelection = customSelection;
        node.marks_ = [for (m in marks_) new RangedMark(m.range, m.mark.clone())];
        node.sourceSegments_ = sourceSegments_.copy();
        node.state = state;
        return node;
    }

    /** Sets the marks, each a byte range of the text and its style. */
    public function marks(marks:Array<RangedMark>):InlineNode {
        this.marks_ = marks;
        return this;
    }

    /** The text of the run (the fallback text of a custom node, empty for an image). */
    public inline function text():String {
        return text_;
    }

    /** The image, when this run is an image. */
    public inline function asImage():Null<ImageNode> {
        return image;
    }

    /** The custom node, when this run is one. */
    public inline function asCustom():Null<MarkdownNode> {
        return custom;
    }

    /** The marks, each a byte range of the text and its style. */
    public inline function markRuns():Array<RangedMark> {
        return marks_;
    }

    @:allow(gpui.base.text)
    function sourceSegments(sourceSegments:Array<SourceSegment>):InlineNode {
        this.sourceSegments_ = sourceSegments;
        return this;
    }

    @:allow(gpui.base.text)
    function selectedSourceRange(selection:Range):Null<Range> {
        return SourceSegment.sourceRangeForSegments(sourceSegments_, selection);
    }

    public function equals(other:Null<InlineNode>):Bool {
        if (other == null || text_ != other.text_ || !ImageNode.eq(image, other.image) || !MarkdownNode.eq(custom, other.custom))
            return false;
        if (marks_.length != other.marks_.length)
            return false;
        for (i in 0...marks_.length) {
            if (!marks_[i].range.equals(other.marks_[i].range) || !marks_[i].mark.equals(other.marks_[i].mark))
                return false;
        }
        return SourceSegment.arrayEquals(sourceSegments_, other.sourceSegments_);
    }

}

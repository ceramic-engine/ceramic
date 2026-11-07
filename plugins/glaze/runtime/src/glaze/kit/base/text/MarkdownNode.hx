// Ported from gpui-kit 0.8.1: crates/base/src/text/markdown_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

/**
 * A custom Markdown node produced by `MarkdownExtensions`.
 */
class MarkdownNode {

    var name_:String;
    var text_:String = '';
    var markdown_:String = '';
    var accessibilityLabel_:Null<String> = null;
    var data_:Dynamic;

    @:allow(glaze.kit.base.text)
    var span:Null<Span> = null;

    /** Create a custom Markdown node with a stable name and typed data. */
    public function new(name:String, data:Dynamic) {
        this.name_ = name;
        this.data_ = data;
    }

    /** Rust `Clone` (the data is shared, like the `Arc`). */
    public function clone():MarkdownNode {
        final node = new MarkdownNode(name_, data_);
        node.text_ = text_;
        node.markdown_ = markdown_;
        node.accessibilityLabel_ = accessibilityLabel_;
        node.span = span != null ? span.copy() : null;
        return node;
    }

    /** Stable name for this custom node. */
    public inline function name():String {
        return name_;
    }

    /** Text representation of this custom node. */
    public inline function asText():String {
        return text_;
    }

    /** Markdown representation of this custom node. */
    public inline function asMarkdown():String {
        return markdown_;
    }

    /** Full-document UTF-8 source byte range, including syntax delimiters. */
    public function sourceRange():Null<glaze.Range> {
        return span != null ? new glaze.Range(span.start, span.end) : null;
    }

    /** Name exposed to accessibility clients, defaulting to the plain text. */
    public function accessibilityName():String {
        return accessibilityLabel_ != null ? accessibilityLabel_ : text_;
    }

    public function accessibilityLabel(label:String):MarkdownNode {
        accessibilityLabel_ = label != '' ? label : null;
        return this;
    }

    /** Plain text, sharing this node's buffer. */
    @:allow(glaze.kit.base.text)
    inline function sharedText():String {
        return text_;
    }

    /** Accessible name, sharing this node's buffer. Defaults to the plain text. */
    @:allow(glaze.kit.base.text)
    inline function sharedAccessibilityName():String {
        return accessibilityName();
    }

    @:allow(glaze.kit.base.text)
    function withInlineSource(source:String):MarkdownNode {
        if (text_ == '') {
            text_ = source;
        }
        if (markdown_ == '') {
            markdown_ = source;
        }
        return this;
    }

    /** Set the text representation of this custom node. */
    public function text(text:String):MarkdownNode {
        text_ = text;
        return this;
    }

    /** Set the Markdown representation of this custom node. */
    public function markdown(markdown:String):MarkdownNode {
        markdown_ = markdown;
        return this;
    }

    /**
     * Read typed data. With `type`, `null` unless the data is of that class
     * (Rust `downcast_ref::<T>()`).
     */
    public function data<T>(?type:Class<T>):Null<T> {
        if (type != null && !Std.isOfType(data_, type))
            return null;
        return cast data_;
    }

    @:allow(glaze.kit.base.text)
    function setSpan(span:Null<Span>):Void {
        this.span = span;
    }

    @:allow(glaze.kit.base.text)
    function toMarkdown():String {
        return markdown_ == '' ? text_ : markdown_;
    }

    public function equals(other:Null<MarkdownNode>):Bool {
        return other != null && name_ == other.name_ && text_ == other.text_ && markdown_ == other.markdown_
            && accessibilityLabel_ == other.accessibilityLabel_ && Span.eq(span, other.span);
    }

    /** `Option<MarkdownNode>` equality. */
    public static function eq(a:Null<MarkdownNode>, b:Null<MarkdownNode>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    public function toString():String {
        return 'MarkdownNode { name: ${haxe.Json.stringify(name_)}, text: ${haxe.Json.stringify(text_)}, markdown: ${haxe.Json.stringify(markdown_)}, span: $span, .. }';
    }

}

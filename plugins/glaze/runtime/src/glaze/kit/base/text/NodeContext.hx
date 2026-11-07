// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.ImageSource;
import glaze.Pixels;
import glaze.Window;
import glaze.kit.base.input.StyledRange;

/**
 * A context for rendering nodes, contains link references.
 *
 * The callbacks are the function types of text_view.rs
 * (`CodeBlockActionsFn`, `CodeBlockHighlighterFn`, `TableActionsFn`,
 * `ImageSourceFn`, `LinkClickHandlerFn`), written out structurally.
 */
class NodeContext {

    /**
     * The byte offset of the node in the original markdown text. Used for
     * incremental updates.
     */
    public var offset:Int = 0;

    public var linkRefs:Map<String, LinkMark> = new Map();

    public var style:TextViewStyle;

    public var codeBlockActions:Null<(codeBlock:CodeBlock, window:Window, cx:App) -> AnyElement> = null;

    public var codeBlockHighlighter:Null<(codeBlock:CodeBlock) -> Array<StyledRange>> = null;

    public var tableActions:Null<(table:TableData, window:Window, cx:App) -> AnyElement> = null;

    public var imageSource:Null<(url:String) -> ImageSource> = null;

    public var linkClickHandler:Null<(url:String, event:ClickEvent, window:Window, cx:App) -> Void> = null;

    public var markdownExtensions:MarkdownExtensions;

    /** This frame's streamed fade-in, when any text is still fading. */
    public var streamFade:Null<StreamFadeFrame> = null;

    /** The application's range highlights, when there are any. */
    public var rangeHighlights:Null<RangeHighlightFrame> = null;

    /** The line being scrolled into view, when there is one. */
    public var reveal:Null<RevealRequest> = null;

    /**
     * The font size the text view inherits this frame, or zero when not
     * resolved; read it through `NodeRender.bodyFontSize`.
     */
    public var bodyFontSize:Pixels = 0;

    /** `NodeContext::default()`. */
    public function new() {
        style = TextViewStyle.defaultValue();
        markdownExtensions = new MarkdownExtensions();
    }

    /** Rust `Clone` (callbacks, style and frames are shared like the `Arc`s). */
    public function clone():NodeContext {
        final cx = new NodeContext();
        cx.offset = offset;
        cx.linkRefs = linkRefs.copy();
        cx.style = style;
        cx.codeBlockActions = codeBlockActions;
        cx.codeBlockHighlighter = codeBlockHighlighter;
        cx.tableActions = tableActions;
        cx.imageSource = imageSource;
        cx.linkClickHandler = linkClickHandler;
        cx.markdownExtensions = markdownExtensions;
        cx.streamFade = streamFade;
        cx.rangeHighlights = rangeHighlights;
        cx.reveal = reveal;
        cx.bodyFontSize = bodyFontSize;
        return cx;
    }

    @:allow(glaze.kit.base.text)
    function imageSourceFor(image:ImageNode):ImageSource {
        return imageSource != null ? imageSource(image.url) : image.source();
    }

    @:allow(glaze.kit.base.text)
    function addRef(identifier:String, link:LinkMark):Void {
        linkRefs.set(identifier, link);
    }

    static final NO_FADES:Array<RangedFade> = [];
    static final NO_BACKGROUNDS:Array<RangedColor> = [];

    /** The fade ranges of the text leaf `key`, in its rendered byte space. */
    @:allow(glaze.kit.base.text)
    function streamFades(key:Null<TextLeafKey>):Array<RangedFade> {
        if (streamFade != null && key != null) {
            final fades = streamFade.fades(key);
            return fades != null ? fades : NO_FADES;
        }
        return NO_FADES;
    }

    /**
     * The range highlight backgrounds of the text leaf `key`, in its
     * rendered byte space.
     */
    @:allow(glaze.kit.base.text)
    function rangeBackgrounds(key:Null<TextLeafKey>):Array<RangedColor> {
        if (rangeHighlights != null && key != null) {
            return rangeHighlights.backgrounds(key);
        }
        return NO_BACKGROUNDS;
    }

    /**
     * The pending reveal, when it starts in the text leaf `key` between
     * `start` and `end`, rebased to `start`.
     */
    @:allow(glaze.kit.base.text)
    function revealAt(key:Null<TextLeafKey>, start:Int, end:Int):Null<RevealAt> {
        return reveal != null ? reveal.at(key, start, end) : null;
    }

    /**
     * Rust `PartialEq`: the link references and the style. The callbacks
     * and markdown extensions are intentionally not compared.
     */
    public function equals(other:Null<NodeContext>):Bool {
        if (other == null || !style.equals(other.style))
            return false;
        var count = 0;
        for (key => link in linkRefs) {
            final otherLink = other.linkRefs.get(key);
            if (otherLink == null || !link.equals(otherLink))
                return false;
            count++;
        }
        for (_ in other.linkRefs.keys())
            count--;
        return count == 0;
    }

}

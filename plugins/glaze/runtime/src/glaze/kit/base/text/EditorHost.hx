// Ported from gpui-kit 0.8.1: crates/base/src/text/editor_host.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.ImageSource;
import glaze.Pixels;
import glaze.Point;
import glaze.Range;
import glaze.TextLayout;
import glaze.Window;
import glaze.WrappedLineLayout;
import glaze.kit.base.text.EditorSeam.EditorSink;
import glaze.kit.base.theme.Theme;
import glaze.util.Utf8;

import glaze.Prelude.*;

using unicode_segmentation.UnicodeSegmentation;

/**
 * Host API for external editors.
 *
 * An editor that lives outside gpui-kit keeps its own document model and
 * hands gpui-kit a `BlockNode` tree, the same tree `TextView` renders.
 * gpui-kit renders it and gives back, per text leaf, the geometry the editor
 * needs for hit-testing, caret placement and platform input (IME) bounds.
 *
 * - In: a `BlockNode` tree whose text leaves carry a host-chosen key (see
 *   `Paragraph.withLeafKey` and `CodeBlock.withLeafKey`), a
 *   `RenderContext`, and per-key decoration ranges.
 * - Out: one opaque `LeafGeometry` per key from `collectLeafGeometry`.
 *
 * The host owns editing semantics, document revisions, accessibility and
 * native input integration.
 *
 * Rust's `impl BlockNode { render_with_id, render }` are `renderWithId` and
 * `render` here (static, use with `using glaze.kit.base.text.EditorHost;`).
 */
class EditorHost {

    /**
     * Parses Markdown with the parser `TextView` uses, including the given
     * extensions, into the block tree. Throws the parser's error message.
     */
    public static function parseMarkdown(source:String, extensions:MarkdownExtensions):Array<BlockNode> {
        final cx = new NodeContext();
        cx.markdownExtensions = extensions;
        final parsed = glaze.kit.base.text.format.MarkdownFormat.parse(source, cx);
        return parsed.blocks;
    }

    /**
     * Renders under a stable host-owned identity. Use a domain ID, not a list
     * position, when inserting, reordering or virtualizing blocks.
     */
    public static function renderWithId(block:BlockNode, id:ElementIdArg, flow:FlowPosition, renderContext:RenderContext, window:Window, cx:App):AnyElement {
        return div()
            .id(id)
            .child(render(block, 0, flow, renderContext, window, cx))
            .intoAnyElement();
    }

    /**
     * Renders the block as TextView does. `ix` identifies the block among its
     * siblings (element ids derive from it).
     */
    public static function render(block:BlockNode, ix:Int, flow:FlowPosition, renderContext:RenderContext, window:Window, cx:App):AnyElement {
        final options = new NodeRenderOptions();
        options.ix = ix;
        options.isFirst = flow.isFirst;
        options.isLast = flow.isLast;
        options.prev = flow.prev;
        return block.renderBlock(options, renderContext.node, window, cx);
    }

    /**
     * Runs `f`, which should prepaint rendered blocks, and returns its result
     * with the geometry every keyed text leaf reported meanwhile.
     *
     * `decorations` maps a leaf key to byte ranges of that leaf's text (atoms
     * count as one `U+FFFC` each) to paint behind the text: the host's
     * selection, find matches, anything. Atom decorations cover the whole atom
     * and paint over its content. Ranges are half-open; empty ranges paint
     * nothing. Scopes nest, and the previous one is restored even if `f`
     * throws.
     *
     * Keys must be unique within one collection scope. Only prepainted leaves
     * are returned; absence is not evidence that a document leaf was removed.
     */
    public static function collectLeafGeometry<R>(decorations:Map<Int, Array<RangedColor>>, f:() -> R):{result:R, leaves:Map<Int, LeafGeometry>} {
        final collector = new Collector(decorations);
        final result = EditorSeam.withSink(collector, f);
        final leaves:Map<Int, LeafGeometry> = new Map();
        for (key => pieces in collector.pieces) {
            if (pieces.length > 0) {
                leaves.set(key, new LeafGeometry(pieces));
            }
        }
        return {result: result, leaves: leaves};
    }

    /** The closest index in a whole-leaf layout for a window point. */
    @:allow(glaze.kit.base.text)
    static function wholeIndexAt(layout:LayoutSnapshot, at:Point):Int {
        final bounds = layout.bounds;
        final lineHeight = layout.lineHeight;
        var top = bounds.top();
        var start = 0;
        final lines = layout.lines;
        for (ix in 0...lines.length) {
            final line = lines[ix];
            final height = Math.max(line.size(lineHeight).height, lineHeight);
            final isLast = ix + 1 == lines.length;
            if (at.y < f32(top + height) || isLast) {
                final local = new Point(
                    Math.max(f32(at.x - bounds.left()), 0.),
                    clamp(f32(at.y - top), 0., Math.max(f32(height - 1.), 0.))
                );
                final index = switch line.closestIndexForPosition(local, lineHeight) {
                    case Ok(ix) | Err(ix): ix;
                }
                return start + index;
            }
            top = f32(top + height);
            start += line.len() + 1;
        }
        return 0;
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    @:allow(glaze.kit.base.text)
    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * What `EditorHost.render` needs besides the node: the text style, code
 * highlighter and Markdown extensions. The builders return the same context.
 */
class RenderContext {

    @:allow(glaze.kit.base.text)
    final node:NodeContext;

    function new(node:NodeContext) {
        this.node = node;
    }

    /**
     * Creates a local rendering context without reading application globals
     * (Rust `RenderContext::new`). The host supplies body typography through
     * its container or `withBodyFontSize`.
     */
    public static function create(style:TextViewStyle):RenderContext {
        final node = new NodeContext();
        node.style = style;
        return new RenderContext(node);
    }

    /** Replaces code highlighting for this context only. */
    public function withCodeBlockHighlighter(highlighter:CodeBlockHighlighterFn):RenderContext {
        node.codeBlockHighlighter = highlighter;
        return this;
    }

    /** Resolves document image URIs. The host owns resource access policy. */
    public function withImageSource(resolver:ImageSourceFn):RenderContext {
        node.imageSource = resolver;
        return this;
    }

    /** Handles link activation. Without a handler, links use `App.openUrl`. */
    public function onLinkClick(handler:LinkClickHandlerFn):RenderContext {
        node.linkClickHandler = handler;
        return this;
    }

    /**
     * Registers a reference-link definition from the host's document. Supply
     * definitions for the entire document, including virtualized blocks.
     */
    public function withLinkReference(identifier:String, link:LinkMark):RenderContext {
        node.linkRefs.set(identifier, link);
        return this;
    }

    /**
     * The context TextView would start from: the global `TextViewDefaults`
     * style and code-block highlighter when set, else the theme's style.
     */
    public static function fromApp(cx:App):RenderContext {
        final theme = Theme.global(cx);
        final defaults = cx.tryGlobal(glaze.kit.base.text.TextView.TextViewDefaults);
        final style = defaults != null && defaults.style() != null ? defaults.style() : TextViewStyle.fromTheme(theme);
        final node = new NodeContext();
        node.style = style;
        node.codeBlockHighlighter = defaults != null ? defaults.codeBlockHighlighter() : null;
        return new RenderContext(node);
    }

    /** Replaces the text style. */
    public function withStyle(style:TextViewStyle):RenderContext {
        node.style = style;
        return this;
    }

    /** Sets the Markdown extensions that render custom nodes. */
    public function withMarkdownExtensions(extensions:MarkdownExtensions):RenderContext {
        node.markdownExtensions = extensions;
        return this;
    }

    /**
     * Sets the font size body text inherits, which the block gaps and heading
     * sizes are relative to.
     */
    public function withBodyFontSize(size:Pixels):RenderContext {
        node.bodyFontSize = size;
        return this;
    }

    /** The text style blocks render with. */
    public function style():TextViewStyle {
        return node.style;
    }

    /** Rust `Clone`. */
    public function clone():RenderContext {
        return new RenderContext(node.clone());
    }

}

/**
 * Where a block stands in the flow it is rendered in, which decides the gaps
 * around it: the first block takes no gap above, the last none below, and a
 * heading or rule counts the block before it. The builders return a new value.
 */
class FlowPosition {

    @:allow(glaze.kit.base.text) final isFirst:Bool;
    @:allow(glaze.kit.base.text) final isLast:Bool;
    @:allow(glaze.kit.base.text) final prev:PrevBlock;

    function new(isFirst:Bool, isLast:Bool, prev:PrevBlock) {
        this.isFirst = isFirst;
        this.isLast = isLast;
        this.prev = prev;
    }

    /**
     * The position of `blocks[ix]` among its siblings. Blocks that render
     * nothing (definitions, breaks) are skipped when looking for the block
     * before it.
     */
    public static function at(blocks:Array<BlockNode>, ix:Int, isLast:Bool):FlowPosition {
        final position = ParsedDocument.flowPosition(blocks, ix);
        return new FlowPosition(position.isFirst, isLast, position.prev);
    }

    /** Overrides whether the block opens its flow, e.g. for a chunk of a long list rendered as a list of its own. */
    public function first(isFirst:Bool):FlowPosition {
        return new FlowPosition(isFirst, isLast, prev);
    }

    /** Overrides whether the block closes its flow. */
    public function last(isLast:Bool):FlowPosition {
        return new FlowPosition(isFirst, isLast, prev);
    }

}

/** Copy mutable frame state, sharing only immutable shaped lines. */
@:allow(glaze.kit.base.text)
class LayoutSnapshot {

    final bounds:Bounds;
    final len:Int;
    final lineHeight:Float;
    final text:String;
    final lines:Array<WrappedLineLayout>;

    function new(layout:TextLayout) {
        bounds = layout.bounds();
        len = layout.len();
        lineHeight = layout.lineHeight();
        text = layout.text();
        lines = layout.lineLayouts().copy();
    }

    function positionForIndex(index:Int):Null<Point> {
        var origin = bounds.origin;
        var start = 0;
        for (line in lines) {
            if (index <= start + line.len()) {
                final p = line.positionForIndex(index - start, lineHeight);
                return p != null ? origin.add(p) : null;
            }
            start += line.len() + 1;
            origin = new Point(origin.x, EditorHost.f32(origin.y + line.size(lineHeight).height));
        }
        return null;
    }

}

/**
 * How a leaf was laid out: one layout for the whole leaf, or (for a mixed
 * paragraph rendered as a flow) single-line text fragments and atom boxes in
 * leaf byte order.
 */
enum Piece {
    Whole(layout:LayoutSnapshot);
    Text(start:Int, layout:LayoutSnapshot);
    Empty(start:Int, bounds:Bounds);
    Atom(range:Range, bounds:Bounds);
}

class PieceTools {

    public static function bounds(piece:Piece):Bounds {
        return switch piece {
            case Whole(layout) | Text(_, layout): layout.bounds;
            case Atom(_, bounds) | Empty(_, bounds): bounds;
        }
    }

    public static function range(piece:Piece):Range {
        return switch piece {
            case Whole(layout): new Range(0, layout.len);
            case Text(start, layout): new Range(start, start + layout.len);
            case Atom(range, _): range;
            case Empty(start, _): new Range(start, start);
        }
    }

}

private class Collector implements EditorSink {

    public final pieces:Map<Int, Array<Piece>> = new Map();
    final decorations:Map<Int, Array<RangedColor>>;

    public function new(decorations:Map<Int, Array<RangedColor>>) {
        this.decorations = decorations;
    }

    function entry(key:Int):Array<Piece> {
        var list = pieces.get(key);
        if (list == null) {
            list = [];
            pieces.set(key, list);
        }
        return list;
    }

    public function report(key:Int, layout:TextLayout):Void {
        pieces.set(key, [Whole(new LayoutSnapshot(layout))]);
    }

    public function beginPieces(key:Int):Void {
        pieces.set(key, []);
    }

    public function reportTextPiece(key:Int, start:Int, layout:TextLayout):Void {
        entry(key).push(Text(start, new LayoutSnapshot(layout)));
    }

    public function reportBoxPiece(key:Int, range:Range, bounds:Bounds):Void {
        entry(key).push(Atom(range, bounds));
    }

    public function reportEmptyPiece(key:Int, start:Int, bounds:Bounds):Void {
        entry(key).push(Empty(start, bounds));
    }

    public function backgrounds(key:Int):Array<RangedColor> {
        final list = decorations.get(key);
        return list != null ? list.copy() : [];
    }

}

/**
 * Where one keyed text leaf was laid out in the last frame.
 *
 * Indices are byte offsets into the leaf's text, where each inline atom
 * (image, custom node) is one `U+FFFC` (3 bytes). Coordinates are window
 * pixels and are valid for the frame that produced them. It is a value, not a
 * handle: later frames do not mutate this snapshot. The host must replace it
 * after content, width, typography or scrolling changes.
 */
class LeafGeometry {

    final pieces:Array<Piece>;

    @:allow(glaze.kit.base.text)
    function new(pieces:Array<Piece>) {
        this.pieces = pieces;
    }

    function whole():Null<LayoutSnapshot> {
        return pieces.length == 1 ? switch pieces[0] {
            case Whole(layout): layout;
            case _: null;
        } : null;
    }

    /** The bounds of the leaf: the union of its pieces. */
    public function bounds():Bounds {
        var result:Null<Bounds> = null;
        for (piece in pieces) {
            final b = PieceTools.bounds(piece);
            result = result == null ? b : result.union(b);
        }
        return result != null ? result : new Bounds();
    }

    /** The length of the leaf's text in bytes, atoms included. */
    public function len():Int {
        var max = 0;
        for (piece in pieces) {
            final end = PieceTools.range(piece).end;
            if (end > max) max = end;
        }
        return max;
    }

    /** Whether the leaf's text is empty (it still has a line box). */
    public function isEmpty():Bool {
        return len() == 0;
    }

    /** The height of a line. */
    public function lineHeight():Float {
        for (piece in pieces) {
            switch piece {
                case Whole(layout) | Text(_, layout): return layout.lineHeight;
                case Empty(_, bounds): return bounds.size.height;
                case Atom(_, _):
            }
        }
        return bounds().size.height;
    }

    /**
     * The height of a caret: the font's ascent plus descent, not the whole
     * line box, which includes leading.
     */
    public function caretHeight():Float {
        final lineHeight = this.lineHeight();
        var found:Null<Float> = null;
        for (piece in pieces) {
            switch piece {
                case Whole(layout) | Text(_, layout):
                    if (layout.lines.length > 0) {
                        final line = layout.lines[0];
                        final h = EditorHost.f32(line.unwrappedLayout.ascent + line.unwrappedLayout.descent);
                        if (h > 0) {
                            found = h;
                            break;
                        }
                    }
                case Atom(_, _) | Empty(_, _):
            }
        }
        final height = found != null ? found : EditorHost.f32(lineHeight * 0.85);
        return Math.min(height, lineHeight);
    }

    /** The top of a caret placed at byte `index`, in window coordinates. */
    public function positionForIndex(index:Int):Point {
        final whole = this.whole();
        if (whole != null) {
            final position = whole.positionForIndex(index < whole.len ? index : whole.len);
            return position != null ? position : bounds().origin;
        }
        // The piece the index starts, else the one it ends (a caret at a
        // fragment boundary sits at the start of the next fragment).
        var piece:Null<Piece> = null;
        for (p in pieces) {
            if (PieceTools.range(p).contains(index)) {
                piece = p;
                break;
            }
        }
        if (piece == null) {
            var i = pieces.length - 1;
            while (i >= 0) {
                if (PieceTools.range(pieces[i]).end == index) {
                    piece = pieces[i];
                    break;
                }
                i--;
            }
        }
        if (piece == null && pieces.length > 0) {
            piece = pieces[pieces.length - 1];
        }
        if (piece == null) {
            return bounds().origin;
        }
        return switch piece {
            case Whole(layout) | Text(_, layout):
                final start = PieceTools.range(piece).start;
                final local = index > start ? index - start : 0;
                final position = layout.positionForIndex(local < layout.len ? local : layout.len);
                position != null ? position : layout.bounds.origin;
            case Empty(_, bounds):
                bounds.origin;
            case Atom(range, bounds):
                final x = index >= range.end ? bounds.right() : bounds.left();
                // Align with the text line: an atom taller than the line keeps
                // the caret at its bottom line.
                final y = Math.max(EditorHost.f32(bounds.bottom() - lineHeight()), bounds.top());
                new Point(x, y);
        }
    }

    /**
     * The byte index of the caret position closest to `at`: glyph halves round
     * to the nearer side, unlike `TextLayout.indexForPosition`.
     */
    public function indexForPosition(at:Point):Int {
        final whole = this.whole();
        if (whole != null) {
            return EditorHost.wholeIndexAt(whole, at);
        }
        // The visual line under the point (pieces whose vertical extent holds
        // it, else the nearest), then the horizontally nearest piece.
        function dy(p:Piece):Float {
            final b = PieceTools.bounds(p);
            return at.y < b.top() ? EditorHost.f32(b.top() - at.y) : (at.y > b.bottom() ? EditorHost.f32(at.y - b.bottom()) : 0.);
        }
        function dx(p:Piece):Float {
            final b = PieceTools.bounds(p);
            return at.x < b.left() ? EditorHost.f32(b.left() - at.x) : (at.x > b.right() ? EditorHost.f32(at.x - b.right()) : 0.);
        }
        var best:Null<Piece> = null;
        var bestDy = 0.;
        var bestDx = 0.;
        for (p in pieces) {
            final pdy = dy(p);
            final pdx = dx(p);
            // Rust `min_by` keeps the first of equal minima.
            if (best == null || pdy < bestDy || (pdy == bestDy && pdx < bestDx)) {
                best = p;
                bestDy = pdy;
                bestDx = pdx;
            }
        }
        if (best == null) {
            return 0;
        }
        final index = switch best {
            case Whole(layout): EditorHost.wholeIndexAt(layout, at);
            // Fragments are one line: take the caret position nearest to the
            // point. Only grapheme boundaries are candidates: an interior byte
            // of a multi-byte character maps to the next glyph's x, so it could
            // tie with (and beat) the real boundary and split the character.
            case Text(start, layout):
                final text = layout.text;
                final candidates:Array<Int> = [];
                final iter = text.graphemeIndices(true);
                while (iter.nextRange()) candidates.push(iter.index);
                candidates.push(Utf8.byteLength(text));
                var nearest = 0;
                var nearestDistance:Null<Float> = null;
                for (i in candidates) {
                    final p = layout.positionForIndex(i);
                    if (p == null) continue;
                    final distance = Math.abs(EditorHost.f32(p.x - at.x));
                    if (nearestDistance == null || distance < nearestDistance) {
                        nearest = i;
                        nearestDistance = distance;
                    }
                }
                start + nearest;
            case Empty(start, _):
                start;
            case Atom(range, bounds):
                at.x < bounds.center().x ? range.start : range.end;
        }
        final len = this.len();
        return index < len ? index : len;
    }

    /** The byte range of the inline atom drawn under `at`, if any. */
    public function atomAt(at:Point):Null<Range> {
        for (piece in pieces) {
            switch piece {
                case Atom(range, bounds) if (bounds.contains(at)):
                    return range;
                case _:
            }
        }
        return null;
    }

}

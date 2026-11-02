// Ported from gpui-kit 0.8.1: crates/base/src/text/text_view.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.ClickEvent;
import gpui.ClipboardItem;
import gpui.ContentMask;
import gpui.Element;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.HitboxBehavior;
import gpui.Hitbox;
import gpui.Hsla;
import gpui.ImageSource;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.MouseButton;
import gpui.Point;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.GlobalState;
import gpui.base.KeyedEntity;
import gpui.base.ScrollBounce;
import gpui.base.Scrollbar;
import gpui.base.TextSelection;
import gpui.base.TouchHandleLayout;
import gpui.base.input.InputActions.Copy;
import gpui.base.input.InputActions.SelectAll;
import gpui.base.input.StyledRange;
import gpui.base.text.PendingReveal.RevealProgress;
import gpui.base.text.MarkdownExtensions.MarkdownBlockParserFn;
import gpui.base.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * Application-wide defaults for TextViews that do not provide explicit
 * presentation or syntax-highlighting overrides. Installed as a global.
 */
class TextViewDefaults {

    @:allow(gpui.base.text) var _style:Null<TextViewStyle> = null;
    @:allow(gpui.base.text) var _codeBlockHighlighter:Null<CodeBlockHighlighterFn> = null;
    @:allow(gpui.base.text) var _inheritTextColor:Bool = false;

    /** Creates defaults that leave every text view as Base renders it. */
    public function new() {}

    function copy():TextViewDefaults {
        final defaults = new TextViewDefaults();
        defaults._style = _style;
        defaults._codeBlockHighlighter = _codeBlockHighlighter;
        defaults._inheritTextColor = _inheritTextColor;
        return defaults;
    }

    /** Sets the style every text view starts from. */
    public function withStyle(style:TextViewStyle):TextViewDefaults {
        final defaults = copy();
        defaults._style = style;
        return defaults;
    }

    /** The style every text view starts from, when set. */
    @:allow(gpui.base.text)
    function style():Null<TextViewStyle> {
        return _style;
    }

    /** The syntax highlighter for fenced code blocks, when set. */
    @:allow(gpui.base.text)
    function codeBlockHighlighter():Null<CodeBlockHighlighterFn> {
        return _codeBlockHighlighter;
    }

    /** Sets the syntax highlighter used for fenced code blocks. */
    public function withCodeBlockHighlighter(highlighter:CodeBlockHighlighterFn):TextViewDefaults {
        final defaults = copy();
        defaults._codeBlockHighlighter = highlighter;
        return defaults;
    }

    /**
     * Sets whether text views without an explicit `TextView.withStyle` follow
     * the text color their container sets, default false.
     *
     * The body text takes that color. On a surface inverted from the page,
     * such as a `primary` fill, links, muted text, code, borders and selection
     * are derived from it too, and the installed syntax highlighter is left
     * out because its colors are made for the page. Enable this only when every
     * window sets a text color at its root, as Component's does.
     */
    public function withInheritTextColor(inherit:Bool):TextViewDefaults {
        final defaults = copy();
        defaults._inheritTextColor = inherit;
        return defaults;
    }

    /** Installs these defaults for the whole application. */
    public function install(cx:App):Void {
        cx.setGlobal(this, TextViewDefaults);
    }

    /** Returns the installed defaults, or the Base ones when none were. */
    public static function global(cx:App):TextViewDefaults {
        final installed = cx.tryGlobal(TextViewDefaults);
        return installed != null ? installed.copy() : new TextViewDefaults();
    }

    /** Whether a syntax highlighter was installed. */
    public function hasCodeBlockHighlighter():Bool {
        return _codeBlockHighlighter != null;
    }

    /** Whether text views follow the text color their container sets. */
    public function inheritTextColor():Bool {
        return _inheritTextColor;
    }

}

/** A plugin that can configure a `TextView` (Rust trait `TextViewPlugin`). */
interface TextViewPlugin {
    function setup(textView:TextView):TextView;
}

/** Rust `impl<P: MarkdownPlugin> TextViewPlugin for P`. */
class MarkdownTextViewPlugin implements TextViewPlugin {

    final plugin:MarkdownPlugin;

    public function new(plugin:MarkdownPlugin) {
        this.plugin = plugin;
    }

    public function setup(textView:TextView):TextView {
        textView._markdownExtensions = textView._markdownExtensions.plugin(plugin);
        return textView;
    }

}

/** Rust `TextViewPrepaintState`. */
private class TextViewPrepaintState {
    public final hitbox:Hitbox;
    /**
     * Where paint has to pull the `maxLines` clip up to, because a glyph line
     * straddles the bottom of the box. `null` leaves the clip at the box edge.
     */
    public final clipBottom:Null<Float>;
    /** The touch handles this view owns, with their hitboxes. */
    public final touchHandles:TouchHandleLayout;

    public function new(hitbox:Hitbox, clipBottom:Null<Float>, touchHandles:TouchHandleLayout) {
        this.hitbox = hitbox;
        this.clipBottom = clipBottom;
        this.touchHandles = touchHandles;
    }
}

/**
 * A text view that can render Markdown or HTML.
 *
 * Goals: a rich text rendering component for Markdown (GFM) or simple HTML
 * (Help messages, Release notes): Heading, Paragraph, Bold, Italic,
 * StrikeThrough, Code, Link, Image, Blockquote, List, Table,
 * HorizontalRule, CodeBlock...
 *
 * Not goals: customization of complex styles, a Markdown editor, an HTML
 * viewer with CSS.
 *
 * Differences with gpui-kit: Rust's `style(TextViewStyle)` builder is
 * `withStyle` (`style()` is the `Styled` refinement here).
 */
class TextView extends Element implements Styled {

    /** Absorbs sub-pixel layout jitter: a line ending within a pixel of the box bottom counts as fitting inside it. */
    static inline final CLIP_EPSILON:Float = 1.;

    final id:ElementId;
    var format:Null<TextViewFormat> = null;
    var text:Null<String> = null;
    @:allow(gpui.base.text) var state:Null<Entity<TextViewState>> = null;
    var textViewStyle:Null<TextViewStyle> = null;
    var _inlineCodeStyle:Null<StyleRefinement> = null;
    var _listStyle:Null<StyleRefinement> = null;
    var _blockquoteStyle:Null<StyleRefinement> = null;
    final styleRefinement:StyleRefinement = new StyleRefinement();
    var _selectable:Bool = true;
    var _selectionFormat:SelectionFormat = Plain;
    var _scrollable:Bool = false;
    var _maxLines:Null<Int> = null;
    var _codeBlockActions:Null<CodeBlockActionsFn> = null;
    var _codeBlockHighlighter:Null<CodeBlockHighlighterFn> = null;
    var _tableActions:Null<TableActionsFn> = null;
    var linkClickHandler:Null<LinkClickHandlerFn> = null;
    var _imageSource:Null<ImageSourceFn> = null;
    var revealHandler:Null<RevealHandlerFn> = null;
    @:allow(gpui.base.text) var _markdownExtensions:MarkdownExtensions;
    var _motion:Null<TextViewMotion> = null;

    // Frame state (Rust `TextViewLayoutState` and `TextViewPrepaintState`).
    var layoutState:Null<Entity<TextViewState>> = null;
    var layoutElement:Null<AnyElement> = null;
    var prepaintState:Null<TextViewPrepaintState> = null;

    function new(id:ElementId) {
        this.id = id;
        _markdownExtensions = new MarkdownExtensions();
    }

    public inline function style():StyleRefinement {
        return styleRefinement;
    }

    /** Create new TextView with managed state (Rust `TextView::new`). */
    public static function create(state:Entity<TextViewState>):TextView {
        final view = new TextView(ElementId.Name(Std.string(state.entityId())));
        view.state = state;
        return view;
    }

    /** Create a new markdown text view. */
    public static function markdown(id:ElementIdArg, markdown:String):TextView {
        final view = new TextView(id);
        view.format = Markdown;
        view.text = markdown;
        return view;
    }

    /** Create a new html text view. */
    public static function html(id:ElementIdArg, html:String):TextView {
        final view = new TextView(id);
        view.format = Html;
        view.text = html;
        return view;
    }

    /**
     * Overrides the source of every document image, including embedded data
     * URLs. The returned source is authoritative: pending or failed loads
     * never fall back to the document URL.
     */
    public function imageSource(resolver:ImageSourceFn):TextView {
        _imageSource = resolver;
        return this;
    }

    /**
     * Refines inline code typography, background, border, radius, and padding
     * over the resolved style. Unspecified properties are inherited.
     */
    public function inlineCodeStyle(style:StyleRefinement):TextView {
        _inlineCodeStyle = @:privateAccess TextViewStyle.normalizeInlineCodeStyle(style);
        return this;
    }

    /** Refines list markers over the resolved style. Unspecified properties are inherited. */
    public function listStyle(style:StyleRefinement):TextView {
        _listStyle = style;
        return this;
    }

    /** Refines blockquotes over the resolved style. Unspecified properties are inherited. */
    public function blockquoteStyle(style:StyleRefinement):TextView {
        _blockquoteStyle = style;
        return this;
    }

    /** Set `TextViewStyle` (Rust `style`). */
    public function withStyle(style:TextViewStyle):TextView {
        textViewStyle = style;
        return this;
    }

    /** Set whether the text view is selectable, default is true. */
    public function selectable(selectable:Bool):TextView {
        _selectable = selectable;
        return this;
    }

    /** Set the `SelectionFormat`, default is `SelectionFormat.Plain`. */
    public function selectionFormat(selectionFormat:SelectionFormat):TextView {
        _selectionFormat = selectionFormat;
        return this;
    }

    /**
     * Set the text view to be scrollable, default is false.
     *
     * When true, the view is meant for large content: it shows a scrollbar,
     * requires the parent to have a fixed height, and renders its content
     * with `gpui.list` in a virtualized way. When false, it expands to fit all
     * content, with no scrollbar.
     */
    public function scrollable(scrollable:Bool):TextView {
        _scrollable = scrollable;
        return this;
    }

    /**
     * Clamp the rendered content to at most `n` lines of body text.
     *
     * The view's height is capped at `n` times the base line height, and a
     * line of glyphs is never cut in half. Check `TextViewState.isClamped` to
     * decide whether to show an "expand" affordance. Ignored when
     * `scrollable` is set.
     */
    public function maxLines(maxLines:Int):TextView {
        _maxLines = maxLines;
        return this;
    }

    /** Set custom block actions for code blocks. */
    public function codeBlockActions(f:(CodeBlock, Window, App) -> IntoElement):TextView {
        _codeBlockActions = (codeBlock, window, cx) -> f(codeBlock, window, cx).intoAnyElement();
        return this;
    }

    /**
     * Adds opt-in syntax highlighting for fenced code blocks.
     *
     * Returned byte ranges are relative to `CodeBlock.code()`. Invalid ranges
     * are discarded. Without this callback, code is unhighlighted.
     */
    public function codeBlockHighlighter(highlighter:CodeBlockHighlighterFn):TextView {
        _codeBlockHighlighter = highlighter;
        return this;
    }

    /**
     * Like `codeBlockHighlighter`, with a highlighter that can be handed to
     * every frame: a code block reuses its highlights only while the
     * highlighter is the same function.
     */
    public function sharedCodeBlockHighlighter(highlighter:CodeBlockHighlighterFn):TextView {
        _codeBlockHighlighter = highlighter;
        return this;
    }

    /** Set custom actions to be rendered below each Markdown table. */
    public function tableActions(f:(TableData, Window, App) -> IntoElement):TextView {
        _tableActions = (table, window, cx) -> f(table, window, cx).intoAnyElement();
        return this;
    }

    /**
     * Handle pointer events on rendered links. Without a handler, links open
     * through `App.openUrl`.
     */
    public function onLinkClick(handler:LinkClickHandlerFn):TextView {
        linkClickHandler = handler;
        return this;
    }

    /**
     * Scroll a container that does not follow scroll requests to the line of
     * `TextViewState.revealRange`: after a frame in which the line was laid
     * out but not visible, the handler receives its bounds in window
     * coordinates.
     */
    public function onReveal(handler:RevealHandlerFn):TextView {
        revealHandler = handler;
        return this;
    }

    /** Replace the Markdown extension registry. */
    public function markdownExtensions(extensions:MarkdownExtensions):TextView {
        _markdownExtensions = extensions;
        return this;
    }

    /**
     * Set the motion policy; see `TextViewMotion`. Without one, the state's
     * own policy applies, which plays no motion by default.
     */
    public function motion(motion:TextViewMotion):TextView {
        _motion = motion;
        return this;
    }

    /**
     * Enable MDX JSX/expression parsing. This disables raw HTML parsing
     * because `markdown-rs` gives HTML priority over MDX when both are enabled.
     */
    public function markdownMdx():TextView {
        _markdownExtensions = _markdownExtensions.clone().mdx();
        return this;
    }

    /**
     * Register a custom block-level Markdown parser. The parser runs during
     * Markdown AST conversion and must be independent of `Window` / `App`.
     */
    public function markdownBlockParser(parser:MarkdownBlockParserFn):TextView {
        final extensions = _markdownExtensions.clone();
        @:privateAccess extensions.pushBlockParser(parser);
        _markdownExtensions = extensions;
        return this;
    }

    /** Register a renderer for a custom block-level Markdown node name. */
    public function markdownBlockRenderer(name:String, renderer:(node:MarkdownNode, window:Window, cx:App) -> IntoElement):TextView {
        final extensions = _markdownExtensions.clone();
        @:privateAccess extensions.pushBlockRenderer(name, renderer);
        _markdownExtensions = extensions;
        return this;
    }

    /** Apply a reusable text view plugin. */
    public function plugin(plugin:TextViewPlugin):TextView {
        return plugin.setup(this);
    }

    /** Apply a Markdown plugin (Rust's blanket `TextViewPlugin` for `MarkdownPlugin`). */
    public function markdownPlugin(plugin:MarkdownPlugin):TextView {
        return new MarkdownTextViewPlugin(plugin).setup(this);
    }

    override public function elementId():Null<ElementId> {
        return id;
    }

    /** Rust's `Display` of `ElementId`, used for the keyed state id. */
    static function idString(id:ElementId):String {
        return switch id {
            case Name(name): name;
            case Integer(value): Std.string(value);
            case NamedInteger(name, value): '$name-$value';
            case _: Std.string(id);
        }
    }

    /**
     * The bottom of the last whole line at or above `y`, with the height of a
     * line where it sits.
     */
    static function lastLineBottomAbove(spans:Array<LineSpan>, y:Float):Null<{bottom:Float, lineHeight:Float}> {
        var lastBottom:Null<Float> = null;
        var lastLineHeight = 0.;
        inline function keep(bottom:Float, lineHeight:Float) {
            if (bottom <= f32(y + CLIP_EPSILON) && (lastBottom == null || bottom > lastBottom)) {
                lastBottom = bottom;
                lastLineHeight = lineHeight;
            }
        }

        for (span in spans) {
            if (span.lineHeight <= 0.) {
                continue;
            }
            var bottom = f32(span.top + span.lineHeight);
            while (bottom <= f32(span.bottom + CLIP_EPSILON)) {
                keep(bottom, span.lineHeight);
                bottom = f32(bottom + span.lineHeight);
            }
            // The span's own bottom covers a last line taller than the rest.
            keep(span.bottom, span.lineHeight);
        }

        return lastBottom != null ? {bottom: lastBottom, lineHeight: lastLineHeight} : null;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    /**
     * Where to clip, given the lines a descendant `Inline` reported. `null`
     * leaves the clip on the box edge.
     *
     * Two things are never shown: half a line of glyphs, and anything with
     * less than a line of itself to show.
     */
    @:allow(tests)
    static function lineSafeClipBottom(spans:Array<LineSpan>, boxBottom:Float, contentBottom:Float):Null<Float> {
        var clip = boxBottom;

        for (span in spans) {
            if (span.lineHeight <= 0.
                || span.top >= boxBottom
                || span.bottom <= f32(boxBottom + CLIP_EPSILON)) {
                continue;
            }
            final wholeLines = Math.ffloor(f32(f32(boxBottom - span.top) / span.lineHeight));
            final lineTop = f32(span.top + f32(span.lineHeight * wholeLines));
            // A line starting on the box edge is not straddling it.
            if (lineTop < f32(boxBottom - CLIP_EPSILON)) {
                clip = Math.min(clip, lineTop);
            }
        }

        final last = lastLineBottomAbove(spans, clip);
        if (last == null) {
            // Leaving the straddling line out would leave nothing at all: it
            // keeps the part that fits instead.
            return null;
        }

        // Snap away a scrap. Only content that continues past the box can leave
        // one.
        if (contentBottom > f32(boxBottom + CLIP_EPSILON)) {
            final strip = f32(clip - last.bottom);
            if (strip > CLIP_EPSILON && strip < last.lineHeight) {
                clip = last.bottom;
            }
        }

        return clip < f32(boxBottom - CLIP_EPSILON) ? clip : null;
    }

    public function requestLayout(_:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        var state = this.state;
        if (state == null) {
            final defaultFormat = format != null ? format : TextViewFormat.Markdown;
            final defaultText = text != null ? text : '';

            state = KeyedEntity.useObserved(window, ElementId.Name('${idString(id)}/state'), TextViewState, cx, (_, cx) -> {
                return defaultFormat == Markdown ? TextViewState.markdown(defaultText, cx) : TextViewState.html(defaultText, cx);
            });
            this.state = state;
        }

        // `maxLines` needs the whole document laid out to snap the clip to a
        // whole line, so it only applies to the fit-content mode.
        final maxLines = _scrollable ? null : _maxLines;

        // Resolve the style.
        final defaults = cx.tryGlobal(TextViewDefaults);
        var textViewStyle:TextViewStyle = if (this.textViewStyle != null) {
            this.textViewStyle;
        }
        else if (defaults != null && defaults._style != null) {
            defaults._style;
        }
        else {
            TextViewStyle.fromTheme(Theme.global(cx));
        }
        // Follow the text color the container sets for its surface, so rich
        // text stays readable in a filled bubble or a selected row.
        var onInvertedSurface = false;
        if (this.textViewStyle == null && defaults != null && defaults._inheritTextColor) {
            final refinedColor = styleRefinement.text != null ? styleRefinement.text.color : null;
            final color = refinedColor != null ? refinedColor : window.textStyle().color;
            if (!color.equals(textViewStyle.foreground())) {
                onInvertedSurface = @:privateAccess textViewStyle.isInvertedBy(color);
                textViewStyle = @:privateAccess textViewStyle.onTextColor(color);
            }
        }
        if (_inlineCodeStyle != null) {
            final style = textViewStyle.inlineCodeStyle().clone();
            style.refine(_inlineCodeStyle);
            textViewStyle = textViewStyle.withInlineCodeStyle(style);
        }
        if (_listStyle != null || _blockquoteStyle != null) {
            var style = textViewStyle;
            if (_listStyle != null) {
                final marker = style.listStyle().clone();
                marker.refine(_listStyle);
                style = style.withListStyle(marker);
            }
            if (_blockquoteStyle != null) {
                final quote = style.blockquoteStyle().clone();
                quote.refine(_blockquoteStyle);
                style = style.withBlockquoteStyle(quote);
            }
            textViewStyle = style;
        }
        final foreground = textViewStyle.foreground();
        final changedStyle = !state.read(cx).textViewStyle.equals(textViewStyle) ? textViewStyle : null;
        final codeBlockHighlighter = _codeBlockHighlighter != null
            ? _codeBlockHighlighter
            : (defaults != null && !onInvertedSurface ? defaults._codeBlockHighlighter : null);

        state.update(cx, (state, cx) -> {
            final previous = state.codeBlockHighlighter;
            final highlighterChanged = previous == null ? codeBlockHighlighter != null : (codeBlockHighlighter == null || !Reflect.compareMethods(previous, codeBlockHighlighter));
            if (changedStyle != null || highlighterChanged) {
                state.preserveSelectionForReflow();
            }
            state.codeBlockActions = _codeBlockActions;
            state.codeBlockHighlighter = codeBlockHighlighter;
            state.tableActions = _tableActions;
            state.linkClickHandler = linkClickHandler;
            state.imageSource = _imageSource;
            state.setMarkdownExtensions(_markdownExtensions, cx);
            if (_motion != null) {
                state.setMotion(_motion);
            }
            state.selectable = _selectable;
            state.selectionFormat = _selectionFormat;
            state.scrollable = _scrollable;
            state.maxLines = maxLines;
            if (changedStyle != null) {
                state.textViewStyle = changedStyle;
            }

            if (text != null) {
                state.setElementText(text, cx);
            }
        });

        final focusHandle = state.read(cx).focusHandle;
        final listState = state.read(cx).listState;
        // Cap the box at `n` body-text lines (the effective text style may be
        // refined by this view's own style); hidden overflow also clips
        // descendant hitboxes to the box during prepaint.
        final maxLinesCap:Null<Float> = if (maxLines != null) {
            final textStyle = window.textStyle();
            if (styleRefinement.text != null) textStyle.refine(styleRefinement.text);
            f32(textStyle.lineHeightInPixels(window.remSize()) * maxLines);
        }
        else {
            null;
        }

        final scrollable = _scrollable;
        final stateEntity = state;
        var el = div()
            .id(ElementId.NamedInteger('text-view-scroll', state.entityId()))
            .keyContext('TextView')
            .trackFocus(focusHandle)
            .when(scrollable, el -> el.sizeFull())
            .whenSome(maxLinesCap, (el, cap) -> el.maxH(gpui.Prelude.px(cap)).overflowHidden())
            .relative()
            .textColor(foreground)
            .onAction(Copy, (_, window, cx) -> {
                final text = StringTools.trim(TextSelection.selectedText(window, cx));
                if (text.length == 0) {
                    cx.propagate();
                    return;
                }
                cx.writeToClipboard(ClipboardItem.newString(text));
            })
            .onAction(SelectAll, (action, window, cx) -> stateEntity.update(cx, (state, cx) -> state.onActionSelectAll(action, window, cx)))
            .map(el -> {
                if (scrollable) {
                    return el.child(new ScrollBounce(ElementId.NamedInteger('text-view-bounce', stateEntity.entityId()), listState, stateEntity));
                }
                else {
                    return el.child(stateEntity);
                }
            })
            // Overlay controls must paint after the document, otherwise rich
            // content and selection backgrounds cover the thumb and hitbox.
            .when(scrollable, el -> el.child(
                div().absolute().inset0().child(
                    Scrollbar.vertical(listState)
                        .id(ElementId.NamedInteger('text-view-scrollbar', stateEntity.entityId()))
                        .viewportFromLayout()
                )
            ))
            .refineStyle(styleRefinement)
            .intoAnyElement();
        final layoutId = el.requestLayout(window, cx);
        layoutState = state;
        layoutElement = el;
        return layoutId;
    }

    public function prepaint(_:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final state = layoutState;
        final maxLinesActive = state.read(cx).maxLines != null;
        if (maxLinesActive) {
            state.read(cx).lineSpans.resize(0);
        }
        // Descendants read the view through the state stack during prepaint (in
        // addition to the paint-time push below): `Inline`s report their line
        // spans when `maxLines` is set, and table cells look for the selection
        // anchor.
        GlobalState.global(cx).pushTextViewState(state);
        layoutElement.prepaint(window, cx);
        GlobalState.global(cx).popTextViewState();

        var clipBottom:Null<Float> = null;
        if (maxLinesActive) {
            final current = state.read(cx);
            final lineSpans = current.lineSpans.copy();
            final contentBottom = current.bounds().bottom();
            // The content keeps its natural height inside the capped box, so
            // this sees everything the box cannot show.
            final clipped = contentBottom > f32(bounds.bottom() + 1.);
            // Notify on change so observers (e.g. an "expand" button gated on
            // `isClamped`) re-render once the flag flips.
            if (current.clamped != clipped) {
                state.update(cx, (state, cx) -> {
                    state.clamped = clipped;
                    cx.notify();
                });
            }
            if (clipped) {
                clipBottom = lineSafeClipBottom(lineSpans, bounds.bottom(), contentBottom);
            }
        }

        final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        // Over the text, so after its hitbox.
        final touchHandles = _selectable ? state.read(cx).selectionAdapter.prepaintTouchHandles(window, cx) : new TouchHandleLayout();
        prepaintState = new TextViewPrepaintState(hitbox, clipBottom, touchHandles);
    }

    public function paint(_:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final state = layoutState;
        final prepaint = prepaintState;
        if (_selectable) {
            state.read(cx).selectionAdapter.beginFrame();
        }

        GlobalState.global(cx).pushTextViewState(state);
        if (prepaint.clipBottom != null) {
            // Snap the `maxLines` clip to the last whole line that fits, so a
            // line of glyphs is never cut in half.
            final mask = new ContentMask(Bounds.fromCorners(bounds.origin, new Point(bounds.right(), prepaint.clipBottom)));
            window.withContentMask(mask, window -> {
                layoutElement.paint(window, cx);
                return true;
            });
        }
        else {
            layoutElement.paint(window, cx);
        }
        GlobalState.global(cx).popTextViewState();

        // Every list has scrolled by now, so the line of a reveal is where it
        // ends up this frame.
        if (state.read(cx).pendingReveal != null) {
            final progress = state.update(cx, (state, _) -> state.pendingReveal != null ? state.pendingReveal.progress() : null);
            if (progress != null) {
                switch progress {
                    case Shown:
                        state.update(cx, (state, _) -> state.pendingReveal = null);
                    case Hidden(line):
                        if (revealHandler != null) {
                            revealHandler(line, window, cx);
                        }
                    case NotLaidOut:
                }
            }
        }

        if (_selectable) {
            final current = state.read(cx);
            final adapter = current.selectionAdapter;
            final scrollOffset = current.scrollOffset();
            final contentBounds = current.bounds();
            final selfScroll = current.scrollable;
            final handleColor = current.textViewStyle.selection().alpha(1.);
            adapter.register(prepaint.hitbox, contentBounds, scrollOffset, selfScroll, window, cx);
            // The handles of a touch selection go over the text, and under
            // whatever is painted over the text after it.
            adapter.paintTouchHandles(prepaint.touchHandles, handleColor, window, cx);
        }
    }

    /** Rust `handle_link_click`. */
    public static function handleLinkClick(handler:Null<LinkClickHandlerFn>, url:String, event:ClickEvent, window:Window, cx:App):Void {
        if (handler != null) {
            handler(url, event, window, cx);
        }
        else if (switch event {
            case Mouse(click): click.up.button == MouseButton.Left || click.up.button == MouseButton.Middle;
            case Keyboard(_): true;
            case Touch(click): !click.longPress;
        }) {
            cx.openUrl(url);
        }
    }

}

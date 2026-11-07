// Ported from gpui-kit 0.8.1: crates/component/src/text/compat.rs (TextView, TextViewPlugin,
// resolve_component_style), crates/component/src/text/mod.rs (base_text_view_style,
// install_text_view_defaults)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.text;

import glaze.AbsoluteLength;
import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.HighlightStyle;
import glaze.ImageSource;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Rems;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.motion.Easing;
import glaze.kit.base.text.CodeBlock;
import glaze.kit.base.text.ImageSourceFn;
import glaze.kit.base.text.LinkClickHandlerFn;
import glaze.kit.base.text.MarkdownExtensions;
import glaze.kit.base.text.MarkdownExtensions.MarkdownBlockParserFn;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.MarkdownPlugin;
import glaze.kit.base.text.RevealHandlerFn;
import glaze.kit.base.text.SelectionFormat;
import glaze.kit.base.text.TableData;
import glaze.kit.base.text.TextView.TextViewDefaults;
import glaze.kit.base.text.TextViewMotion;
import glaze.kit.base.text.TextViewState;
import glaze.kit.theme.Theme;

/**
 * A bundle of component `TextView` configuration that can be applied in one
 * call (Rust trait `TextViewPlugin`). Markdown plugins go through
 * `TextView.markdownPlugin`, Rust's blanket implementation for every
 * `MarkdownPlugin`.
 */
interface TextViewPlugin {
    /** Applies this plugin's configuration to `textView`. */
    function setup(textView:TextView):TextView;
}

/**
 * The component-level rich text element.
 *
 * The rendering, parsing and selection all live in the Base
 * `glaze.kit.base.text.TextView`; this wrapper keeps the component API: the
 * component `TextViewStyle` folded onto the active theme, and the
 * `streamFade` timing of the theme.
 *
 * Differences with gpui-kit: Rust's `style(TextViewStyle)` builder is
 * `withStyle` (`style()` is the `Styled` refinement here), Rust's
 * `TextView::new(&state)` is `TextView.create(state)`, the module functions
 * `markdown(source)` / `html(source)` are `TextView.markdownAt` /
 * `TextView.htmlAt` (their id is the caller's code location). Rust's
 * `TextViewLayoutState` / `TextViewPrepaintState` (kept there for source
 * compatibility) are the inner element of this one.
 */
class TextView extends Element implements Styled {

    /**
     * How long a word of streamed text takes to reach full color (seconds).
     * Measured frame by frame from claude.ai: a chunk lands as about 6 words
     * every 100 ms and goes from transparent to solid in about 280 ms.
     */
    static inline final STREAM_FADE:Float = 0.28;

    /**
     * How much later each further word of the same chunk starts (seconds).
     * `stagger x words` has to stay well under the interval between chunks,
     * while the fade has to outlast it.
     */
    static inline final STREAM_FADE_STAGGER:Float = 0.01;

    final id:ElementId;

    @:allow(glaze.kit.text)
    var inner:glaze.kit.base.text.TextView;

    var textStyle:Null<TextViewStyle> = null;

    var _motion:Null<TextViewMotion> = null;

    /**
     * `null` leaves the state's own policy alone; `false` turns a fade off
     * that an earlier frame turned on.
     */
    var _streamFade:Null<Bool> = null;

    var element:Null<AnyElement> = null;

    function new(id:ElementId, inner:glaze.kit.base.text.TextView) {
        this.id = id;
        this.inner = inner;
    }

    public inline function style():StyleRefinement {
        return inner.style();
    }

    /** Creates a text view rendering an existing `TextViewState` (Rust `TextView::new`). */
    public static function create(state:Entity<TextViewState>):TextView {
        return new TextView(ElementId.Name(Std.string(state.entityId())), glaze.kit.base.text.TextView.create(state));
    }

    /** Creates a text view that parses `text` as Markdown. */
    public static function markdown(id:ElementIdArg, text:String):TextView {
        final id:ElementId = id;
        return new TextView(id, glaze.kit.base.text.TextView.markdown(id, text));
    }

    /** Creates a text view that parses `text` as HTML. */
    public static function html(id:ElementIdArg, text:String):TextView {
        final id:ElementId = id;
        return new TextView(id, glaze.kit.base.text.TextView.html(id, text));
    }

    /** Creates a Markdown text view identified by the caller's code location (Rust `text::markdown`). */
    public static function markdownAt(source:String, ?pos:haxe.PosInfos):TextView {
        return markdown(ElementId.CodeLocation(pos.fileName, pos.lineNumber), source);
    }

    /** Creates an HTML text view identified by the caller's code location (Rust `text::html`). */
    public static function htmlAt(source:String, ?pos:haxe.PosInfos):TextView {
        return html(ElementId.CodeLocation(pos.fileName, pos.lineNumber), source);
    }

    /**
     * Overrides the source of every document image, including embedded data
     * URLs, for both rendering and intrinsic-size measurement. The returned
     * source is authoritative.
     */
    public function imageSource(resolver:ImageSourceFn):TextView {
        inner = inner.imageSource(resolver);
        return this;
    }

    /** Sets the style, folded onto the one derived from the active theme (Rust `style`). */
    public function withStyle(style:TextViewStyle):TextView {
        textStyle = style;
        return this;
    }

    /** Sets whether the text can be selected with the mouse. */
    public function selectable(value:Bool):TextView {
        inner = inner.selectable(value);
        return this;
    }

    /**
     * Refines inline code typography, background, border, radius, and padding
     * over the resolved theme or explicit style. Unspecified properties are
     * inherited.
     */
    public function inlineCodeStyle(style:StyleRefinement):TextView {
        inner = inner.inlineCodeStyle(style);
        return this;
    }

    /**
     * Refines bullet and number list markers over the resolved theme or
     * explicit style. The text color also outlines unchecked task-list
     * checkboxes.
     */
    public function listStyle(style:StyleRefinement):TextView {
        inner = inner.listStyle(style);
        return this;
    }

    /** Refines the blockquote container, including its left border. */
    public function blockquoteStyle(style:StyleRefinement):TextView {
        inner = inner.blockquoteStyle(style);
        return this;
    }

    /** Sets whether a copied selection carries Markdown source or plain text. */
    public function selectionFormat(value:SelectionFormat):TextView {
        inner = inner.selectionFormat(value);
        return this;
    }

    /** Sets whether the view scrolls its own content. */
    public function scrollable(value:Bool):TextView {
        inner = inner.scrollable(value);
        return this;
    }

    /**
     * Fades streamed text in the way Claude reveals a reply: the words a
     * `setText` or `pushStr` adds start transparent and light up one after
     * another, each reaching full color over 280 ms. Text that replaces rather
     * than extends the current content shows at once, and reduced motion
     * disables the fade. Use `motion` for other timing.
     */
    public function streamFade(value:Bool):TextView {
        _streamFade = value;
        return this;
    }

    /** Sets the motion policy explicitly, overriding `streamFade`'s theme timing. */
    public function motion(motion:TextViewMotion):TextView {
        _motion = motion;
        return this;
    }

    /** Clamps the rendered content to `value` lines. */
    public function maxLines(value:Int):TextView {
        inner = inner.maxLines(value);
        return this;
    }

    /** Renders an element in the corner of every fenced code block. */
    public function codeBlockActions(f:(CodeBlock, Window, App) -> IntoElement):TextView {
        inner = inner.codeBlockActions(f);
        return this;
    }

    /** Renders an element in the corner of every table. */
    public function tableActions(f:(TableData, Window, App) -> IntoElement):TextView {
        inner = inner.tableActions(f);
        return this;
    }

    /** Handles link clicks instead of opening the URL. */
    public function onLinkClick(handler:LinkClickHandlerFn):TextView {
        inner = inner.onLinkClick(handler);
        return this;
    }

    /**
     * Scrolls a container that ignores scroll requests to the line of
     * `TextViewState.revealRange`, with the line's window bounds.
     */
    public function onReveal(handler:RevealHandlerFn):TextView {
        inner = inner.onReveal(handler);
        return this;
    }

    /** Sets which Markdown extensions the parser accepts. */
    public function markdownExtensions(value:MarkdownExtensions):TextView {
        inner = inner.markdownExtensions(value);
        return this;
    }

    /** Enables the MDX Markdown extensions. */
    public function markdownMdx():TextView {
        inner = inner.markdownMdx();
        return this;
    }

    /** Parses custom block nodes out of the Markdown AST. */
    public function markdownBlockParser(parser:MarkdownBlockParserFn):TextView {
        inner = inner.markdownBlockParser(parser);
        return this;
    }

    /** Renders the custom block nodes named `name`. */
    public function markdownBlockRenderer(name:String, renderer:(node:MarkdownNode, window:Window, cx:App) -> IntoElement):TextView {
        inner = inner.markdownBlockRenderer(name, renderer);
        return this;
    }

    /** Applies a plugin, which may install any of the hooks above. */
    public function plugin(plugin:TextViewPlugin):TextView {
        return plugin.setup(this);
    }

    /** Applies a Markdown plugin (Rust's `TextViewPlugin` for every `MarkdownPlugin`). */
    public function markdownPlugin(plugin:MarkdownPlugin):TextView {
        inner = inner.markdownPlugin(plugin);
        return this;
    }

    override public function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(_:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        var inner = this.inner;
        if (textStyle != null) {
            // `requestLayout` runs every frame, so this asks whether the
            // caller ever replaced the theme (an identity comparison against
            // the shared default) rather than comparing two whole themes.
            // Rust compiles this only with a highlighter feature: here it
            // follows `Highlighter.enabled`.
            if (glaze.kit.highlighter.Highlighter.enabled
                && textStyle.highlightTheme != glaze.kit.highlighter.HighlightTheme.defaultLight()) {
                inner = inner.sharedCodeBlockHighlighter(sharedCodeBlockHighlighter(textStyle.highlightTheme));
            }
            inner = inner.withStyle(resolveComponentStyle(Theme.global(cx), textStyle));
        }
        var motion = _motion;
        if (motion == null && _streamFade != null) {
            motion = if (!_streamFade) {
                new TextViewMotion();
            }
            else {
                new TextViewMotion()
                    .withStreamFade(STREAM_FADE)
                    .withStreamFadeStagger(STREAM_FADE_STAGGER)
                    .withStreamFadeEasing(Easing.EaseOut);
            }
        }
        if (motion != null) {
            inner = inner.motion(motion);
        }
        final element = inner.intoAnyElement();
        this.element = element;
        return element.requestLayout(window, cx);
    }

    public function prepaint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        element.prepaint(window, cx);
    }

    public function paint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        element.paint(window, cx);
    }

    /** Derives the Base rich-text style installed by the component theme adapter (Rust `base_text_view_style`). */
    public static function baseTextViewStyle(theme:Theme):glaze.kit.base.text.TextViewStyle {
        final radius = theme.semanticTokens().radius.md;
        final table = new StyleRefinement();
        table.cornerRadiusTopLeft = AbsoluteLength.Pixels(radius);
        table.cornerRadiusTopRight = AbsoluteLength.Pixels(radius);
        table.cornerRadiusBottomLeft = AbsoluteLength.Pixels(radius);
        table.cornerRadiusBottomRight = AbsoluteLength.Pixels(radius);
        final codeBlock = new StyleRefinement();
        codeBlock.cornerRadiusTopLeft = table.cornerRadiusTopLeft;
        codeBlock.cornerRadiusTopRight = table.cornerRadiusTopRight;
        codeBlock.cornerRadiusBottomLeft = table.cornerRadiusBottomLeft;
        codeBlock.cornerRadiusBottomRight = table.cornerRadiusBottomRight;
        final tableHead = StyleBuilder.build(s -> s.bg(theme.tableHead).textColor(theme.tableHeadForeground));

        return glaze.kit.base.text.TextViewStyle.defaultValue()
            .withForeground(theme.foreground)
            .withMutedForeground(theme.mutedForeground)
            .withLink(theme.link)
            .withSelection(theme.selection)
            .withCodeBackground(theme.muted)
            .withBorder(theme.border)
            .withCodeBlock(codeBlock)
            .withTable(table)
            .withTableHead(tableHead)
            .withInlineCode(new HighlightStyle(null, null, null, theme.accent))
            .withDark(theme.isDark());
    }

    /**
     * Installs the component theme's text view defaults (Rust
     * `install_text_view_defaults`), called by `Theme.syncBase`.
     *
     * The component code block highlighter is installed when the TextMate
     * highlighter is on (`glaze.kit.highlighter.Highlighter.enable`),
     * where Rust installs it with its `tree-sitter` or `syntect` feature.
     */
    public static function installTextViewDefaults(theme:Theme, cx:App):Void {
        // Component's Root sets the theme foreground, so every container that
        // sets its own text color is one a text view should follow.
        var defaults = new TextViewDefaults()
            .withStyle(baseTextViewStyle(theme))
            .withInheritTextColor(true);

        if (glaze.kit.highlighter.Highlighter.enabled) {
            defaults = defaults.withCodeBlockHighlighter(componentCodeBlockHighlighter(theme.highlightTheme));
        }

        defaults.install(cx);
    }

    /**
     * The code block highlighter of the component (Rust
     * `component_code_block_highlighter`, its syntect version): grammars keep
     * no state between calls, and the highlights of an unchanged block are
     * cached by the text view itself.
     */
    @:allow(glaze.kit, tests)
    static function componentCodeBlockHighlighter(highlightTheme:glaze.kit.highlighter.HighlightTheme):glaze.kit.base.text.CodeBlockHighlighterFn {
        final resolver = highlightTheme.resolver();
        return block -> {
            final lang = block.lang();
            return lang != null ? glaze.kit.highlighter.TextMateBackend.highlightCode(lang, block.code(), resolver) : [];
        };
    }

    static final SHARED_CAPACITY:Int = 4;

    /** The registry generation the shared highlighters were built at. */
    static var sharedGeneration:Int = 0;

    static final sharedHighlighters:Array<{theme:glaze.kit.highlighter.HighlightTheme, highlighter:glaze.kit.base.text.CodeBlockHighlighterFn}> = [];

    /**
     * The `componentCodeBlockHighlighter` for `highlightTheme`, built once
     * and handed out again for the same theme (Rust
     * `shared_code_block_highlighter`).
     *
     * A code block reuses its highlights only while the highlighter is the
     * same function, and a text view with a custom theme is laid out every
     * frame. Only the most recent few themes are kept. Entries are also keyed
     * on the grammar registry generation: registering a grammar drops them,
     * so code blocks painted before it existed are highlighted again.
     */
    @:allow(glaze.kit, tests)
    static function sharedCodeBlockHighlighter(highlightTheme:glaze.kit.highlighter.HighlightTheme):glaze.kit.base.text.CodeBlockHighlighterFn {
        return sharedCodeBlockHighlighterAt(highlightTheme, glaze.kit.highlighter.TextMateGrammars.generation);
    }

    @:allow(glaze.kit, tests)
    static function sharedCodeBlockHighlighterAt(highlightTheme:glaze.kit.highlighter.HighlightTheme, generation:Int):glaze.kit.base.text.CodeBlockHighlighterFn {
        if (sharedGeneration != generation) {
            sharedGeneration = generation;
            sharedHighlighters.resize(0);
        }
        for (entry in sharedHighlighters) {
            if (entry.theme == highlightTheme)
                return entry.highlighter;
        }
        final highlighter = componentCodeBlockHighlighter(highlightTheme);
        if (sharedHighlighters.length == SHARED_CAPACITY) {
            sharedHighlighters.shift();
        }
        sharedHighlighters.push({theme: highlightTheme, highlighter: highlighter});
        return highlighter;
    }

    /**
     * Folds a component `TextViewStyle` onto the one the theme already
     * derived (Rust `resolve_component_style`).
     *
     * The legacy type carries `StyleRefinement`s that callers filled in
     * partially, so each one is refined onto the themed value rather than
     * replacing it: a caller who set only the white space keeps the themed
     * padding and colors.
     */
    @:allow(glaze.kit, tests)
    static function resolveComponentStyle(theme:Theme, legacy:TextViewStyle):glaze.kit.base.text.TextViewStyle {
        final themed = baseTextViewStyle(theme);

        function refined(base:StyleRefinement, overlay:StyleRefinement):StyleRefinement {
            final base = base.clone();
            base.refine(overlay);
            return base;
        }
        final codeBlock = refined(themed.codeBlock(), legacy.codeBlock);
        final table = refined(themed.table(), legacy.table);
        final tableHead = refined(themed.tableHead(), legacy.tableHead);
        final tableCell = refined(themed.tableCell(), legacy.tableCell);

        final base = themed.inlineCode();
        final inlineCode = new HighlightStyle(base.color, base.fontWeight, base.fontStyle, base.backgroundColor, base.underline, base.strikethrough,
            base.fadeOut);
        refineHighlightStyle(inlineCode, legacy.inlineCode);

        // `isDark` only ever turns on: the component theme already answered the
        // question, and a legacy style left at its `false` default must not undo
        // a dark theme.
        final isDark = themed.isDark() || legacy.isDark;

        final headingBaseFontSize = legacy.headingBaseFontSize;
        final headingFontSize = legacy.headingFontSize;
        // A style that never touched heading sizes keeps the Base default, which
        // scales headings with the body text; only an explicit base size or
        // resolver pins them to pixels.
        final pinsHeadingSize = headingFontSize != null || headingBaseFontSize != TextViewStyle.defaultValue().headingBaseFontSize;
        return themed
            .withParagraphGap(legacy.paragraphGap)
            .withHeading(level -> {
                if (!pinsHeadingSize) {
                    return new StyleRefinement();
                }
                final defaultSize = (switch level {
                    case 1: 2.;
                    case 2: 1.5;
                    case 3: 1.25;
                    case 4: 1.125;
                    case _: 1.;
                } : Rems).toPixels(headingBaseFontSize);
                final textSize = headingFontSize == null ? defaultSize : headingFontSize(level, headingBaseFontSize);
                return StyleBuilder.build(s -> s.textSize(textSize));
            })
            .withCodeBlock(codeBlock)
            .withTable(table)
            .withTableHead(tableHead)
            .withTableCell(tableCell)
            .withInlineCode(inlineCode)
            .withDark(isDark);
    }

    static function refineHighlightStyle(style:HighlightStyle, refinement:HighlightStyle):Void {
        if (refinement.color != null) {
            style.color = refinement.color;
        }
        if (refinement.fontWeight != null) {
            style.fontWeight = refinement.fontWeight;
        }
        if (refinement.fontStyle != null) {
            style.fontStyle = refinement.fontStyle;
        }
        if (refinement.backgroundColor != null) {
            style.backgroundColor = refinement.backgroundColor;
        }
        if (refinement.underline != null) {
            style.underline = refinement.underline;
        }
        if (refinement.strikethrough != null) {
            style.strikethrough = refinement.strikethrough;
        }
        if (refinement.fadeOut != null) {
            style.fadeOut = refinement.fadeOut;
        }
    }

}

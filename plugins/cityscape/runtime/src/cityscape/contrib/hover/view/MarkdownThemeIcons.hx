// New code for Cityscape (not a port): the `$(name)` theme icons of a
// markdown string with `supportThemeIcons` (Monaco's markdownRenderer.ts
// rewrites them with `renderLabelWithIcons` into codicon spans), drawn by the
// kit's text view through a markdown plugin.
package cityscape.contrib.hover.view;

import cityscape.view.Codicons;
import glaze.App;
import glaze.Window;
import glaze.kit.base.text.InlineElement;
import glaze.kit.base.text.InlineRenderContext;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.MarkdownParseContext;
import glaze.kit.base.text.MarkdownPlugin;
import markdown.Markdown as MdParser;
import markdown.ParseOptions as MdParseOptions;
import markdown.mdast.Node.Node as MdNode;
import markdown.mdast.NodeTools as MdNodeTools;

using glaze.kit.base.StyledExt;

/**
 * The theme icons of markdown strings.
 *
 * Monaco renders a markdown string with `supportThemeIcons` with marked,
 * then replaces each `$(name)` of the HTML (`$(name~modifier)` too) by
 * `<span class="codicon codicon-name"></span>`; an escaped `\$(name)` stays
 * as the text `$(name)` (`markdownEscapeEscapedIcons`). In a hover the icon
 * is the codicon glyph at the size and in the color of the text
 * (hoverWidget.css: `font-size: inherit; color: inherit; vertical-align:
 * middle`).
 *
 * Here `transform` replaces each `$(name)` of the source by an image of the
 * `cityscape-codicon:` scheme, outside fenced code and code spans, and
 * `ThemeIconPlugin` draws it in the text view as an inline codicon. Monaco
 * also replaces the icons of code spans (it rewrites the whole HTML, so
 * `<code><span class="codicon codicon-zap"></span> run</code>`): the plugin
 * renders a code span with icons itself (`splitCodeSpan`), the icons of
 * fenced code stay as text in both (Monaco's code blocks are highlighted
 * token by token, the `$(name)` of a block comes out as text).
 */
class MarkdownThemeIcons {

    /** The scheme of the image an icon becomes. */
    public static inline final SCHEME = 'cityscape-codicon:';

    /**
     * The markdown with its `$(name)` icons as `![](cityscape-codicon:name)`
     * images (the modifier dropped), outside code; the source itself when
     * it has none.
     */
    public static function transform(source:String):String {
        if (source.indexOf('$(') == -1) {
            return source;
        }
        final bytes = haxe.io.Bytes.ofString(source);
        // the byte ranges of code (fenced, indented, spans) and of HTML, left as they are
        final excluded:Array<Int> = [];
        try {
            final root = MdParser.toMdast(source, MdParseOptions.gfm());
            function walk(node:MdNode):Void {
                switch node {
                    case Code(c):
                        if (c.position != null) {
                            excluded.push(c.position.start.offset);
                            excluded.push(c.position.end.offset);
                        }
                    case InlineCode(c):
                        if (c.position != null) {
                            excluded.push(c.position.start.offset);
                            excluded.push(c.position.end.offset);
                        }
                    case Html(h):
                        if (h.position != null) {
                            excluded.push(h.position.start.offset);
                            excluded.push(h.position.end.offset);
                        }
                    case _:
                        final children = MdNodeTools.children(node);
                        if (children != null) {
                            for (child in children) {
                                walk(child);
                            }
                        }
                }
            }
            walk(root);
        }
        catch (e:Dynamic) {
            // not parsed: every icon is replaced
        }
        inline function isExcluded(offset:Int):Bool {
            var result = false;
            var k = 0;
            while (k < excluded.length) {
                if (offset >= excluded[k] && offset < excluded[k + 1]) {
                    result = true;
                    break;
                }
                k += 2;
            }
            return result;
        }
        final out = new haxe.io.BytesBuffer();
        var changed = false;
        var i = 0;
        final n = bytes.length;
        while (i < n) {
            final c = bytes.get(i);
            if (c == '$'.code && i + 1 < n && bytes.get(i + 1) == '('.code && !isEscaped(bytes, i) && !isExcluded(i)) {
                final end = iconEnd(bytes, i + 2);
                if (end != -1) {
                    final name = bytes.getString(i + 2, end - (i + 2));
                    final tilde = name.indexOf('~');
                    out.addString('![](' + SCHEME + (tilde >= 0 ? name.substring(0, tilde) : name) + ')');
                    changed = true;
                    i = end + 1;
                    continue;
                }
            }
            out.addByte(c);
            i++;
        }
        return changed ? out.getBytes().toString() : source;
    }

    /**
     * The parts of a code span with icons: its text between the `$(name)`
     * icons, and the icons (their modifier dropped); null when it has no
     * icon. In a code span the backslash is text, so `\$(name)` stays as it
     * is (Monaco: `markdownEscapeEscapedIcons` doubles the backslash, marked
     * keeps both in `<code>`, `renderLabelWithIcons` takes one back with the
     * escaped icon: the text keeps its backslashes).
     */
    public static function splitCodeSpan(value:String):Null<Array<CodeSpanPart>> {
        if (value.indexOf('$(') == -1) {
            return null;
        }
        final bytes = haxe.io.Bytes.ofString(value);
        final n = bytes.length;
        var parts:Null<Array<CodeSpanPart>> = null;
        var textStart = 0;
        var i = 0;
        while (i < n) {
            if (bytes.get(i) == '$'.code && i + 1 < n && bytes.get(i + 1) == '('.code && !(i > 0 && bytes.get(i - 1) == '\\'.code)) {
                final end = iconEnd(bytes, i + 2);
                if (end != -1) {
                    if (parts == null) {
                        parts = [];
                    }
                    if (i > textStart) {
                        parts.push(new CodeSpanPart(bytes.getString(textStart, i - textStart), null));
                    }
                    final name = bytes.getString(i + 2, end - (i + 2));
                    final tilde = name.indexOf('~');
                    parts.push(new CodeSpanPart(null, tilde >= 0 ? name.substring(0, tilde) : name));
                    i = end + 1;
                    textStart = i;
                    continue;
                }
            }
            i++;
        }
        if (parts != null && textStart < n) {
            parts.push(new CodeSpanPart(bytes.getString(textStart, n - textStart), null));
        }
        return parts;
    }

    /**
     * Whether the `$` at `index` is escaped (an odd number of backslashes
     * before it).
     */
    static function isEscaped(bytes:haxe.io.Bytes, index:Int):Bool {
        var count = 0;
        var k = index - 1;
        while (k >= 0 && bytes.get(k) == '\\'.code) {
            count++;
            k--;
        }
        return count % 2 == 1;
    }

    /**
     * The index of the `)` closing an icon name starting at `start`
     * (`ThemeIcon.iconNameExpression` and its modifier:
     * `[A-Za-z0-9-]+(~[A-Za-z]+)?`), -1 when it is not one.
     */
    static function iconEnd(bytes:haxe.io.Bytes, start:Int):Int {
        var k = start;
        final n = bytes.length;
        while (k < n && isNameChar(bytes.get(k))) {
            k++;
        }
        if (k == start) {
            return -1;
        }
        if (k < n && bytes.get(k) == '~'.code) {
            final modifier = k + 1;
            k = modifier;
            while (k < n && isLetter(bytes.get(k))) {
                k++;
            }
            if (k == modifier) {
                return -1;
            }
        }
        return k < n && bytes.get(k) == ')'.code ? k : -1;
    }

    static inline function isLetter(c:Int):Bool {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code);
    }

    static inline function isNameChar(c:Int):Bool {
        return isLetter(c) || (c >= '0'.code && c <= '9'.code) || c == '-'.code;
    }

}

/**
 * A part of a code span with icons: a text, or an icon (`CodeSpanIcons`).
 */
class CodeSpanPart {
    public final text:Null<String>;
    public final icon:Null<String>;
    public function new(text:Null<String>, icon:Null<String>) {
        this.text = text;
        this.icon = icon;
    }
}

/**
 * The data of a code span with icons rendered by `ThemeIconPlugin`.
 */
class CodeSpanIcons {
    public final parts:Array<CodeSpanPart>;
    public function new(parts:Array<CodeSpanPart>) {
        this.parts = parts;
    }
}

/**
 * Draws the `cityscape-codicon:` images of `MarkdownThemeIcons.transform`
 * as inline codicons: an em square of the text's size, in the text's color,
 * placed on the line like Monaco's (`vertical-align: middle`). An id
 * without outline draws nothing (Monaco's codicon font has no glyph for it
 * either). A code span with `$(name)` icons (`MarkdownThemeIcons
 * .splitCodeSpan`) is rendered as one inline box in the style of the text
 * view's inline code (`codeStyle`: Monaco's `<code>` around the codicon
 * spans), its text and its icons in a row.
 */
class ThemeIconPlugin extends MarkdownPlugin {

    public static inline final NAME = 'cityscape-codicon';

    /**
     * The distance from the top of the icon to the baseline, in em, measured
     * on the real Monaco 0.52.2 (a 12 pixel hover: the 12 pixel icon's top
     * 10.1 pixels above the baseline of the text, glaze-golden scratchpad
     * cs-polish-probe s3-widgets.js).
     */
    static inline final BASELINE = 0.84;

    /** The style of the box of a code span with icons (the text view's inline code style). */
    final codeStyle:Null<glaze.StyleRefinement>;

    public function new(?codeStyle:glaze.StyleRefinement) {
        this.codeStyle = codeStyle;
    }

    public function name():String {
        return NAME;
    }

    public function parse(node:MdNode, cx:MarkdownParseContext):Null<MarkdownNode> {
        return switch node {
            case Image(image) if (image.url != null && StringTools.startsWith(image.url, MarkdownThemeIcons.SCHEME)):
                new MarkdownNode(NAME, image.url.substr(MarkdownThemeIcons.SCHEME.length)).text('');
            case InlineCode(code):
                final parts = MarkdownThemeIcons.splitCodeSpan(code.value);
                parts != null ? new MarkdownNode(NAME, new CodeSpanIcons(parts)).text(code.value) : null;
            case _:
                null;
        }
    }

    override public function renderInline(node:MarkdownNode, context:InlineRenderContext, window:Window, cx:App):Null<InlineElement> {
        final codeSpan:Null<CodeSpanIcons> = node.data(CodeSpanIcons);
        if (codeSpan != null) {
            return renderCodeSpan(codeSpan, context, window, cx);
        }
        final id:Null<String> = node.data(String);
        final data = id != null ? Codicons.svg(id) : null;
        if (data == null) {
            return null;
        }
        final size:Float = context.fontSize();
        final element = glaze.Prelude.svg()
            .data(data)
            .w(glaze.Prelude.px(size))
            .h(glaze.Prelude.px(size))
            .flexShrink0()
            .textColor(context.textStyle().color);
        return new InlineElement(element).withBaseline(size * BASELINE);
    }

    /**
     * A code span with icons: its text and its icons (an em square each,
     * centered on the line like `vertical-align: middle`) in a row in the
     * inline code style; the row is as high as a line of the text, so its
     * bottom aligns with the surrounding text's.
     */
    function renderCodeSpan(codeSpan:CodeSpanIcons, context:InlineRenderContext, window:Window, cx:App):InlineElement {
        final size:Float = context.fontSize();
        final color = context.textStyle().color;
        final row = glaze.Prelude.div().flex().flexRow().itemsCenter().textSize(glaze.Prelude.px(size)).textColor(color);
        if (codeStyle != null) {
            row.refineStyle(codeStyle);
        }
        for (part in codeSpan.parts) {
            if (part.icon != null) {
                final data = Codicons.svg(part.icon);
                if (data != null) {
                    row.child(glaze.Prelude.svg().data(data).w(glaze.Prelude.px(size)).h(glaze.Prelude.px(size)).flexShrink0().textColor(color));
                }
            }
            else if (part.text != null) {
                row.child(part.text);
            }
        }
        return new InlineElement(row);
    }

}

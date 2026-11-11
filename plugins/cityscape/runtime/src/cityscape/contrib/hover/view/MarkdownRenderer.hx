// New code for Cityscape (not a port): renders the markdown of hovers and
// of the documentation of completions with the Glaze kit's text view, its
// code blocks colored by the tokenization of the editor (Monaco's
// MarkdownRenderer, src/vs/editor/browser/widget/markdownRenderer, colors
// code blocks with `tokenizeToString`).
package cityscape.contrib.hover.view;

import cityscape.Cityscape;
import cityscape.base.common.Color;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages.ITokenizationSupport;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorWidgets;
import cityscape.contrib.hover.view.MarkdownThemeIcons.ThemeIconPlugin;
import glaze.App;
import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.Range;
import glaze.kit.base.input.StyledRange;
import glaze.kit.base.text.CodeBlock;
import glaze.kit.base.text.CodeBlockHighlighterFn;
import glaze.kit.base.text.TextView;
import glaze.kit.theme.Theme;
import markdown.Markdown as MdParser;
import markdown.ParseOptions as MdParseOptions;
import markdown.mdast.Node.Node as MdNode;
import markdown.mdast.NodeTools as MdNodeTools;

/**
 * Renders markdown (`IMarkdownString`) for the editor's widgets: the kit's
 * base `TextView` in the editor's colors (`editorHoverWidget.foreground`,
 * `textLink.foreground`, `textCodeBlock.background`), with a code block
 * highlighter that tokenizes the code of a fenced block with the tokenizer
 * of its language in the editor's context (Monaco colors hover code blocks
 * with its own tokenization too). The language of a block is a language id
 * or name of the context; blocks of another language are not colored.
 */
class MarkdownRenderer {

    /**
     * Draws the `$(name)` icons of the strings with `supportThemeIcons`
     * (`MarkdownThemeIcons`), the code spans with icons in `codeStyle`.
     */
    static function themeIconPlugin(codeStyle:glaze.StyleRefinement):ThemeIconPlugin {
        return new ThemeIconPlugin(codeStyle);
    }

    /**
     * The code block highlighter of a context for its current token colors
     * (kept by the context, so that a text view can keep the highlights of
     * a block between frames).
     */
    public static function codeBlockHighlighter(context:Cityscape):CodeBlockHighlighterFn {
        final colorMap = context.tokenizationRegistry.getColorMap();
        final cached = @:privateAccess context._markdownCodeBlockHighlighter;
        if (cached != null && cached.colorMap == colorMap) {
            return cached.highlighter;
        }
        final highlighter:CodeBlockHighlighterFn = block -> highlightCodeBlock(context, block.lang(), block.code());
        @:privateAccess context._markdownCodeBlockHighlighter = {colorMap: colorMap, highlighter: highlighter};
        return highlighter;
    }

    /**
     * The tokenization support of a code block language (an id, an alias
     * or a name of the context's languages).
     */
    static function tokenizationSupportOf(context:Cityscape, lang:Null<String>):Null<ITokenizationSupport> {
        if (lang == null || lang.length == 0) {
            return null;
        }
        var languageId:Null<String> = null;
        if (context.languageService.isRegisteredLanguageId(lang)) {
            languageId = lang;
        }
        else {
            languageId = context.languageService.getLanguageIdByLanguageName(lang);
        }
        if (languageId == null) {
            return null;
        }
        return context.tokenizationRegistry.getOrCreate(languageId);
    }

    static function hslaOf(color:Color):Hsla {
        final rgba = color.rgba;
        return new glaze.Rgba(rgba.r / 255, rgba.g / 255, rgba.b / 255, rgba.a).toHsla();
    }

    /**
     * The styled byte ranges of a code block: each token in the color and
     * font style the theme gives its metadata.
     */
    public static function highlightCodeBlock(context:Cityscape, lang:Null<String>, code:String):Array<StyledRange> {
        final result:Array<StyledRange> = [];
        final support = tokenizationSupportOf(context, lang);
        final colorMap = context.tokenizationRegistry.getColorMap();
        if (support == null || colorMap == null) {
            return result;
        }
        var state = support.getInitialState();
        var byteOffset = 0;
        final lines = code.split('\n');
        for (lineIndex in 0...lines.length) {
            var line = lines[lineIndex];
            if (line.length > 0 && StringTools.fastCodeAt(line, line.length - 1) == '\r'.code) {
                line = line.substr(0, line.length - 1);
            }
            final hasEOL = lineIndex < lines.length - 1;
            var tokenized:Null<cityscape.common.Languages.EncodedTokenizationResult> = null;
            try {
                tokenized = support.tokenizeEncoded(line, hasEOL, state);
            }
            catch (e:Dynamic) {
                tokenized = null;
            }
            if (tokenized != null) {
                final tokens = tokenized.tokens;
                final count = tokens.length >> 1;
                for (i in 0...count) {
                    final startIndex:Int = tokens[i * 2];
                    final metadata:Int = tokens[i * 2 + 1];
                    final endIndex:Int = i + 1 < count ? (tokens[(i + 1) * 2] : Int) : line.length;
                    if (endIndex <= startIndex) {
                        continue;
                    }
                    final foreground:Int = TokenMetadata.getForeground(metadata);
                    final fontStyle:Int = TokenMetadata.getFontStyle(metadata);
                    final style = new HighlightStyle();
                    if (foreground > 0 && foreground < colorMap.length) {
                        style.color = hslaOf(colorMap[foreground]);
                    }
                    if ((fontStyle & (FontStyle.Italic : Int)) != 0) {
                        style.fontStyle = glaze.FontStyle.Italic;
                    }
                    if ((fontStyle & (FontStyle.Bold : Int)) != 0) {
                        style.fontWeight = glaze.FontWeight.BOLD;
                    }
                    final s = byteOffset + utf8Length(line, 0, startIndex);
                    final e = byteOffset + utf8Length(line, 0, endIndex);
                    result.push(new StyledRange(new Range(s, e), style));
                }
                state = tokenized.endState;
            }
            // the line and its '\n' (and the removed '\r')
            byteOffset += utf8Length(lines[lineIndex], 0, lines[lineIndex].length) + (hasEOL ? 1 : 0);
        }
        return result;
    }

    static function utf8Length(s:String, start:Int, end:Int):Int {
        var bytes = 0;
        var i = start;
        while (i < end && i < s.length) {
            final c = StringTools.fastCodeAt(s, i);
            if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
                bytes += 4;
                i += 2;
            }
            else {
                bytes += c < 0x80 ? 1 : (c < 0x800 ? 2 : 3);
                i++;
            }
        }
        return bytes;
    }

    //#region Hover markdown

    /**
     * The tags Monaco's sanitizer keeps that the kit's text view renders
     * itself (`basicMarkupHtmlTags`); `small`, `code` and `br` are turned
     * into markdown or lines here, the other allowed tags (`span`, `sub`,
     * `kbd`...) are dropped and their text kept.
     */
    static final KEPT_TAGS = ['strong', 'b', 'em', 'i', 'u', 's', 'del', 'strike', 'mark', 'small'];

    /**
     * The blocks of a hover's markdown (Monaco renders it with marked into
     * a `div.rendered-markdown` styled by hoverWidget.css): one per top
     * level block, with hoverWidget.css's margins. The HTML of a markdown
     * string that does not allow it (`supportHtml`) shows as text like
     * Monaco's escaping; with `supportHtml`, `<code>` becomes inline code,
     * `<br>` a line break, `<small>` smaller lines (the lines of a paragraph
     * wholly in `<small>`; elsewhere its text is kept at the paragraph's
     * size), the formatting tags of the kit's text view stay and the other
     * tags are dropped, their text kept. With `supportThemeIcons`, the
     * `$(name)` icons are drawn (`MarkdownThemeIcons`).
     */
    static function withThemeIcons(blocks:Array<HoverMarkdownBlock>, md:IMarkdownString):Array<HoverMarkdownBlock> {
        if (md.supportThemeIcons == true) {
            for (b in blocks) {
                b.themeIcons = true;
            }
        }
        return blocks;
    }

    public static function parseHoverMarkdown(md:IMarkdownString, fontSize:Float):Array<HoverMarkdownBlock> {
        final value = md.value != null ? md.value : '';
        var source = transformHtml(value, md.supportHtml == true);
        if (md.supportThemeIcons == true) {
            source = MarkdownThemeIcons.transform(source);
        }
        final blocks:Array<HoverMarkdownBlock> = [];
        var root:MdNode;
        try {
            root = MdParser.toMdast(source, MdParseOptions.gfm());
        }
        catch (e:Dynamic) {
            blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Paragraph, value, null, false));
            applyMargins(blocks, fontSize);
            return withThemeIcons(blocks, md);
        }
        final bytes = haxe.io.Bytes.ofString(source);
        final children = MdNodeTools.children(root);
        // link reference definitions do not render: each block gets them,
        // so that its references resolve
        final definitions = new StringBuf();
        for (child in children) {
            switch child {
                case Definition(_):
                    definitions.add('\n\n');
                    definitions.add(slice(bytes, child));
                case _:
            }
        }
        final defs = definitions.toString();
        for (child in children) {
            final text = slice(bytes, child);
            switch child {
                case Definition(_):
                case Paragraph(p):
                    final split = splitSmallLines(bytes, p.children);
                    final startsWithStrong = p.children.length > 0 && switch p.children[0] {
                        case Strong(_): true;
                        case Html(h): final tag = parseTag(h.value); tag != null && !tag.closing && (tag.name == 'strong' || tag.name == 'b');
                        case _: false;
                    };
                    if (split != null) {
                        for (line in split) {
                            @:privateAccess line.source = line.source + defs;
                        }
                        blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Paragraph, text, split, startsWithStrong));
                    }
                    else {
                        blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Paragraph, removeSmallTags(bytes, child) + defs, null, startsWithStrong));
                    }
                case ThematicBreak(_):
                    blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Rule, text, null, false));
                case Code(_):
                    blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Code, text, null, false));
                case List(l):
                    blocks.push(new HoverMarkdownBlock(l.ordered ? HoverMarkdownBlockKind.OrderedList : HoverMarkdownBlockKind.UnorderedList, removeSmallTags(bytes, child) + defs, null, false));
                case Heading(_):
                    blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Heading, removeSmallTags(bytes, child) + defs, null, false));
                case Blockquote(_):
                    blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Blockquote, removeSmallTags(bytes, child) + defs, null, false));
                case _:
                    blocks.push(new HoverMarkdownBlock(HoverMarkdownBlockKind.Other, removeSmallTags(bytes, child) + defs, null, false));
            }
        }
        applyMargins(blocks, fontSize);
        return withThemeIcons(blocks, md);
    }

    /**
     * hoverWidget.css and the browser's defaults: `p`, `.code`, `ul` and the
     * headings 8 pixels above and below (none above the first and below the
     * last `p`, `.code` or `ul`), `ol` and `blockquote` 1em (`blockquote` 40
     * pixels on the sides), `hr` 4 above, -4 below and -8 on the sides (it
     * spans the hover's width).
     */
    static function applyMargins(blocks:Array<HoverMarkdownBlock>, fontSize:Float):Void {
        for (i in 0...blocks.length) {
            final block = blocks[i];
            switch block.kind {
                case HoverMarkdownBlockKind.Paragraph | HoverMarkdownBlockKind.Code | HoverMarkdownBlockKind.UnorderedList | HoverMarkdownBlockKind.Heading:
                    block.marginTop = 8;
                    block.marginBottom = 8;
                case HoverMarkdownBlockKind.OrderedList:
                    block.marginTop = fontSize;
                    block.marginBottom = fontSize;
                case HoverMarkdownBlockKind.Blockquote:
                    block.marginTop = fontSize;
                    block.marginBottom = fontSize;
                    block.marginLeft = 40;
                    block.marginRight = 40;
                case HoverMarkdownBlockKind.Rule:
                    block.marginTop = 4;
                    block.marginBottom = -4;
                    block.marginLeft = -8;
                    block.marginRight = -8;
                case _:
            }
            final firstOrLastRule = block.kind == HoverMarkdownBlockKind.Paragraph || block.kind == HoverMarkdownBlockKind.Code || block.kind == HoverMarkdownBlockKind.UnorderedList;
            if (firstOrLastRule && i == 0) {
                block.marginTop = 0;
            }
            if (firstOrLastRule && i == blocks.length - 1) {
                block.marginBottom = 0;
            }
        }
    }

    /**
     * Two adjoining vertical margins as CSS collapses them: the largest
     * positive one plus the most negative one.
     */
    public static function collapseMargins(a:Float, b:Float):Float {
        return std.Math.max(std.Math.max(a, b), 0) + std.Math.min(std.Math.min(a, b), 0);
    }

    static function slice(bytes:haxe.io.Bytes, node:MdNode):String {
        final position = MdNodeTools.position(node);
        if (position == null) {
            return '';
        }
        return bytes.getString(position.start.offset, position.end.offset - position.start.offset);
    }

    /**
     * An HTML tag (`<name ...>`, `</name>`, `<name/>`), null for anything
     * else (comments, text).
     */
    static function parseTag(html:String):Null<{name:String, closing:Bool}> {
        final trimmed = StringTools.trim(html);
        if (trimmed.length < 3 || StringTools.fastCodeAt(trimmed, 0) != '<'.code || StringTools.fastCodeAt(trimmed, trimmed.length - 1) != '>'.code) {
            return null;
        }
        var i = 1;
        final closing = StringTools.fastCodeAt(trimmed, 1) == '/'.code;
        if (closing) {
            i++;
        }
        final start = i;
        while (i < trimmed.length) {
            final c = StringTools.fastCodeAt(trimmed, i);
            if (!((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code))) {
                break;
            }
            i++;
        }
        if (i == start) {
            return null;
        }
        return {name: trimmed.substring(start, i).toLowerCase(), closing: closing};
    }

    static function escapeHtml(html:String):String {
        return html.split('&').join('&amp;').split('<').join('&lt;').split('>').join('&gt;');
    }

    /**
     * The markdown with its HTML handled like Monaco's renderer and
     * sanitizer (see `parseHoverMarkdown`), the tags the text view knows
     * and `<small>` kept.
     */
    static function transformHtml(source:String, supportHtml:Bool):String {
        if (source.indexOf('<') == -1) {
            return source;
        }
        var root:MdNode;
        try {
            root = MdParser.toMdast(source, MdParseOptions.gfm());
        }
        catch (e:Dynamic) {
            return source;
        }
        final bytes = haxe.io.Bytes.ofString(source);
        final edits:Array<{start:Int, end:Int, text:String}> = [];
        function walk(node:MdNode):Void {
            switch node {
                case Html(h):
                    final position = h.position;
                    if (position == null) {
                        return;
                    }
                    final start = position.start.offset;
                    final end = position.end.offset;
                    if (!supportHtml) {
                        edits.push({start: start, end: end, text: escapeHtml(h.value)});
                        return;
                    }
                    final tag = parseTag(h.value);
                    if (tag == null) {
                        if (StringTools.startsWith(StringTools.trim(h.value), '<!--')) {
                            edits.push({start: start, end: end, text: ''});
                        }
                        return;
                    }
                    if (tag.name == 'code') {
                        edits.push({start: start, end: end, text: '`'});
                    }
                    else if (tag.name == 'br') {
                        final nextIsNewline = end < bytes.length && (bytes.get(end) == '\n'.code || bytes.get(end) == '\r'.code);
                        edits.push({start: start, end: end, text: nextIsNewline ? '\\' : '\\\n'});
                    }
                    else if (KEPT_TAGS.indexOf(tag.name) == -1) {
                        // a single inline tag (block level HTML is left to the text view)
                        final trimmed = StringTools.trim(h.value);
                        if (trimmed.indexOf('<', 1) == -1) {
                            edits.push({start: start, end: end, text: ''});
                        }
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
        if (edits.length == 0) {
            return source;
        }
        haxe.ds.ArraySort.sort(edits, (a, b) -> a.start - b.start);
        final result = new StringBuf();
        var offset = 0;
        for (edit in edits) {
            if (edit.start < offset) {
                continue;
            }
            result.add(bytes.getString(offset, edit.start - offset));
            result.add(edit.text);
            offset = edit.end;
        }
        result.add(bytes.getString(offset, bytes.length - offset));
        return result.toString();
    }

    static function isSmallTag(node:MdNode, closing:Bool):Bool {
        return switch node {
            case Html(h):
                final tag = parseTag(h.value);
                tag != null && tag.name == 'small' && tag.closing == closing;
            case _: false;
        }
    }

    /**
     * The source of a node without its `<small>` tags (their text kept at
     * the size of the paragraph).
     */
    static function removeSmallTags(bytes:haxe.io.Bytes, node:MdNode):String {
        final position = MdNodeTools.position(node);
        if (position == null) {
            return '';
        }
        final ranges:Array<{start:Int, end:Int}> = [];
        function walk(n:MdNode):Void {
            if (isSmallTag(n, false) || isSmallTag(n, true)) {
                final p = MdNodeTools.position(n);
                if (p != null) {
                    ranges.push({start: p.start.offset, end: p.end.offset});
                }
                return;
            }
            final children = MdNodeTools.children(n);
            if (children != null) {
                for (child in children) {
                    walk(child);
                }
            }
        }
        walk(node);
        return sliceWithout(bytes, position.start.offset, position.end.offset, ranges);
    }

    static function sliceWithout(bytes:haxe.io.Bytes, start:Int, end:Int, ranges:Array<{start:Int, end:Int}>):String {
        haxe.ds.ArraySort.sort(ranges, (a, b) -> a.start - b.start);
        final result = new StringBuf();
        var offset = start;
        for (r in ranges) {
            if (r.start < offset || r.end > end) {
                continue;
            }
            result.add(bytes.getString(offset, r.start - offset));
            offset = r.end;
        }
        result.add(bytes.getString(offset, end - offset));
        return result.toString();
    }

    /**
     * The lines of a paragraph (split at its hard breaks) when one of them
     * is wholly in `<small>`, else null.
     */
    static function splitSmallLines(bytes:haxe.io.Bytes, children:Array<MdNode>):Null<Array<HoverMarkdownLine>> {
        final segments:Array<Array<MdNode>> = [[]];
        for (child in children) {
            switch child {
                case Break(_):
                    segments.push([]);
                case _:
                    segments[segments.length - 1].push(child);
            }
        }
        var anySmall = false;
        final lines:Array<HoverMarkdownLine> = [];
        for (segment in segments) {
            if (segment.length == 0) {
                continue;
            }
            final first = segment[0];
            final last = segment[segment.length - 1];
            final firstPosition = MdNodeTools.position(first);
            final lastPosition = MdNodeTools.position(last);
            if (firstPosition == null || lastPosition == null) {
                return null;
            }
            var opens = 0;
            for (n in segment) {
                if (isSmallTag(n, false)) {
                    opens++;
                }
            }
            final ranges:Array<{start:Int, end:Int}> = [];
            for (n in segment) {
                if (isSmallTag(n, false) || isSmallTag(n, true)) {
                    final p = MdNodeTools.position(n);
                    ranges.push({start: p.start.offset, end: p.end.offset});
                }
            }
            final small = segment.length >= 2 && opens == 1 && isSmallTag(first, false) && isSmallTag(last, true);
            if (small) {
                anySmall = true;
            }
            lines.push(new HoverMarkdownLine(StringTools.trim(sliceWithout(bytes, firstPosition.start.offset, lastPosition.end.offset, ranges)), small));
        }
        return anySmall ? lines : null;
    }

    /**
     * The text view style of the hovers: the editor's hover colors, the
     * inline code of hoverWidget.css (`--monaco-monospace-font`, the size of
     * the text, `0 0.4em` padding, 3 pixels radius,
     * `textCodeBlock.background`) and its code blocks (`.code`: the editor's
     * font, no box).
     */
    /**
     * The inline code of hoverWidget.css (see `hoverTextViewStyle`).
     */
    public static function inlineCodeStyle(editor:ICodeEditor, size:Float, foreground:Hsla, codeBackground:Hsla):glaze.StyleRefinement {
        return glaze.StyleBuilder.build(s -> s
            .fontFamily(EditorWidgets.monospaceFontFamily(editor))
            .textSize(glaze.Prelude.px(size))
            .textColor(foreground)
            .bg(codeBackground)
            .px(glaze.Prelude.px(size * 0.4))
            .rounded(glaze.Prelude.px(3)));
    }

    public static function hoverTextViewStyle(editor:ICodeEditor, size:Float, foreground:Hsla, window:glaze.Window, cx:App):glaze.kit.base.text.TextViewStyle {
        final theme = Theme.global(cx);
        final link = EditorWidgets.color(editor, 'textLink.foreground', theme.link);
        final codeBackground = EditorWidgets.color(editor, 'textCodeBlock.background', theme.muted);
        final inlineCode = inlineCodeStyle(editor, size, foreground, codeBackground);
        final fontInfo = editor.getOption(cityscape.common.config.EditorOptions.EditorOption.fontInfo);
        final codeBlock = glaze.StyleBuilder.build(s -> s
            .fontFamily(EditorWidgets.editorFontFamily(editor))
            .textSize(glaze.Prelude.px(fontInfo.fontSize))
            .lineHeight(glaze.Prelude.px(fontInfo.lineHeight))
            .bg(glaze.Hsla.transparentBlack())
            .border0()
            .p0()
            .rounded(glaze.Prelude.px(0)));
        final remSize:Float = window != null ? window.remSize() : 16.0;
        return glaze.kit.text.TextView.baseTextViewStyle(theme)
            .withForeground(foreground)
            .withMutedForeground(foreground.opacity(0.7))
            .withLink(link)
            .withCodeBackground(codeBackground)
            .withInlineCode(new glaze.HighlightStyle(foreground, null, null, codeBackground))
            .withInlineCodeStyle(inlineCode)
            .withCodeBlock(codeBlock)
            .withParagraphGap(glaze.Prelude.rems(8 / remSize))
            .withDark(EditorWidgets.isDark(editor));
    }

    /**
     * Renders the blocks of a hover's markdown (`parseHoverMarkdown`,
     * changed by the caller if need be) as Monaco's `.hover-contents`: 4
     * and 8 pixels of padding, the blocks with their collapsed margins, at
     * the hover's text size and line height (`<small>` lines at the
     * browser's `smaller`, on lines as high as the others), links handled by
     * `onLinkClick` when given.
     */
    public static function renderHoverMarkdown(editor:ICodeEditor, id:String, blocks:Array<HoverMarkdownBlock>, window:glaze.Window, cx:App, ?onLinkClick:(url:String) -> Void):glaze.Div {
        final theme = Theme.global(cx);
        final fontInfo = editor.getOption(cityscape.common.config.EditorOptions.EditorOption.fontInfo);
        final fontSize:Float = fontInfo.fontSize;
        final lineHeight:Float = fontInfo.lineHeight;
        final hoverForeground = EditorWidgets.color(editor, 'editorHoverWidget.foreground', EditorWidgets.color(editor, 'editor.foreground', theme.popoverForeground));
        final border = EditorWidgets.color(editor, 'editorHoverWidget.border', EditorWidgets.color(editor, 'editorWidget.border', theme.border));
        final highlighter = codeBlockHighlighter(editor.context);

        // a line of the hover keeps the line height of the paragraph (its
        // strut) when its text is smaller (`<small>`)
        function textView(viewId:String, source:String, size:Float, foreground:Hsla, themeIcons:Bool):glaze.IntoElement {
            var view = TextView.markdown(viewId, source)
                .withStyle(hoverTextViewStyle(editor, size, foreground, window, cx))
                .selectable(true)
                .sharedCodeBlockHighlighter(highlighter)
                // no language label on the code blocks (Monaco shows none)
                .codeBlockActions((_, _, _) -> glaze.Prelude.div());
            if (themeIcons) {
                view = view.markdownPlugin(themeIconPlugin(inlineCodeStyle(editor, size, foreground, EditorWidgets.color(editor, 'textCodeBlock.background', theme.muted))));
            }
            if (onLinkClick != null) {
                view = view.onLinkClick((url, _, _, _) -> onLinkClick(url));
            }
            return glaze.Prelude.div().minW0().textSize(glaze.Prelude.px(size)).lineHeight(glaze.Prelude.px(lineHeight)).child(view);
        }

        final contents = glaze.Prelude.div().flex().flexCol().px(glaze.Prelude.px(8)).py(glaze.Prelude.px(4))
            .textSize(glaze.Prelude.px(fontSize)).lineHeight(glaze.Prelude.px(lineHeight));
        for (i in 0...blocks.length) {
            final block = blocks[i];
            final blockId = id + '-' + i;
            final foreground = block.foreground != null ? block.foreground : hoverForeground;
            final box = glaze.Prelude.div().flex().flexCol().minW0().flexNone();
            final top = i == 0 ? block.marginTop : collapseMargins(blocks[i - 1].marginBottom, block.marginTop);
            box.mt(glaze.Prelude.px(top));
            if (i == blocks.length - 1) {
                box.mb(glaze.Prelude.px(block.marginBottom));
            }
            box.ml(glaze.Prelude.px(block.marginLeft)).mr(glaze.Prelude.px(block.marginRight));
            box.pt(glaze.Prelude.px(block.paddingTop)).pb(glaze.Prelude.px(block.paddingBottom))
                .pl(glaze.Prelude.px(block.paddingLeft)).pr(glaze.Prelude.px(block.paddingRight));
            if (block.background != null) {
                box.bg(block.background);
            }
            box.textColor(foreground);
            switch block.kind {
                case HoverMarkdownBlockKind.Rule:
                    // hoverContribution.ts: `hr { border-top: 1px solid <editorHoverWidget.border 50%> }`
                    box.h(glaze.Prelude.px(1)).bg(border.opacity(0.5));
                case HoverMarkdownBlockKind.Paragraph if (block.lines != null):
                    for (j in 0...block.lines.length) {
                        final line = block.lines[j];
                        // `small { font-size: smaller }`: the size divided by 1.2
                        box.child(textView(blockId + '-' + j, line.source, line.small ? fontSize / 1.2 : fontSize, foreground, block.themeIcons));
                    }
                case _:
                    box.child(textView(blockId, block.source, fontSize, foreground, block.themeIcons));
            }
            contents.child(box);
        }
        return contents;
    }

    //#endregion

    /**
     * The text view of a markdown string, in the colors of the editor's
     * widgets (`foregroundKey`, by default the hover's).
     */
    public static function render(editor:ICodeEditor, id:String, markdown:IMarkdownString, cx:App, ?foregroundKey:String):TextView {
        final theme = Theme.global(cx);
        final foreground = EditorWidgets.color(editor, foregroundKey != null ? foregroundKey : 'editorHoverWidget.foreground', EditorWidgets.color(editor, 'editor.foreground', theme.popoverForeground));
        final link = EditorWidgets.color(editor, 'textLink.foreground', theme.link);
        final codeBackground = EditorWidgets.color(editor, 'textCodeBlock.background', theme.muted);
        final style = glaze.kit.text.TextView.baseTextViewStyle(theme)
            .withForeground(foreground)
            .withMutedForeground(foreground.opacity(0.7))
            .withLink(link)
            .withCodeBackground(codeBackground)
            .withDark(EditorWidgets.isDark(editor));
        final fontFamily = EditorWidgets.editorFontFamily(editor);
        final codeStyle = new glaze.StyleRefinement();
        var view = TextView.markdown(id, markdown.supportThemeIcons == true && markdown.value != null ? MarkdownThemeIcons.transform(markdown.value) : markdown.value)
            .withStyle(style)
            .selectable(true)
            .sharedCodeBlockHighlighter(codeBlockHighlighter(editor.context));
        if (markdown.supportThemeIcons == true) {
            view = view.markdownPlugin(themeIconPlugin(glaze.StyleBuilder.build(s -> s.bg(codeBackground))));
        }
        return view;
    }

}

/**
 * The kind of a top level block of a hover's markdown.
 */
enum abstract HoverMarkdownBlockKind(Int) from Int to Int {
    var Paragraph = 0;
    /** `---` (`hr`) */
    var Rule = 1;
    /** A fenced or indented code block (`.code`) */
    var Code = 2;
    var UnorderedList = 3;
    var OrderedList = 4;
    var Heading = 5;
    var Blockquote = 6;
    /** Tables, HTML blocks... */
    var Other = 7;
}

/**
 * A line of a paragraph split at its hard breaks (`HoverMarkdownBlock.lines`).
 */
class HoverMarkdownLine {

    /** The markdown of the line, without its `<small>` tags. */
    public var source(default, null):String;
    /** Whether the line is wholly in `<small>`. */
    public final small:Bool;

    public function new(source:String, small:Bool) {
        this.source = source;
        this.small = small;
    }

}

/**
 * A top level block of a hover's markdown and its box (hoverWidget.css), a
 * host may change the box before rendering
 * (`MarkdownRenderer.renderHoverMarkdown`).
 */
class HoverMarkdownBlock {

    public final kind:HoverMarkdownBlockKind;
    /** The markdown of the block. */
    public final source:String;
    /** The lines of a paragraph with `<small>` lines, else null. */
    public final lines:Null<Array<HoverMarkdownLine>>;
    /** Whether the block is a paragraph starting with bold text. */
    public final startsWithStrong:Bool;
    /** Whether the `$(name)` icons of the block are drawn (`supportThemeIcons`). */
    public var themeIcons:Bool = false;

    /** The margins, collapsed with the margins of the next and previous blocks like CSS (negative ones included). */
    public var marginTop:Float = 0;
    public var marginBottom:Float = 0;
    public var marginLeft:Float = 0;
    public var marginRight:Float = 0;
    public var paddingTop:Float = 0;
    public var paddingBottom:Float = 0;
    public var paddingLeft:Float = 0;
    public var paddingRight:Float = 0;
    public var background:Null<glaze.Hsla> = null;
    /** The text color, null for the hover's. */
    public var foreground:Null<glaze.Hsla> = null;

    public function new(kind:HoverMarkdownBlockKind, source:String, lines:Null<Array<HoverMarkdownLine>>, startsWithStrong:Bool) {
        this.kind = kind;
        this.source = source;
        this.lines = lines;
        this.startsWithStrong = startsWithStrong;
    }

}

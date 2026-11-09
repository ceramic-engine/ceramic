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
import glaze.App;
import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.Range;
import glaze.kit.base.input.StyledRange;
import glaze.kit.base.text.CodeBlock;
import glaze.kit.base.text.CodeBlockHighlighterFn;
import glaze.kit.base.text.TextView;
import glaze.kit.theme.Theme;

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
        final view = TextView.markdown(id, markdown.value)
            .withStyle(style)
            .selectable(true)
            .sharedCodeBlockHighlighter(codeBlockHighlighter(editor.context));
        return view;
    }

}

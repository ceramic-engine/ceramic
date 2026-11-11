// New code for Cityscape (not a port): the blocks of the markdown of hovers
// (MarkdownRenderer.parseHoverMarkdown): the margins of hoverWidget.css and
// their collapsing, `<small>` lines, the HTML Monaco's sanitizer keeps or
// escapes, the `$(name)` theme icons (markdownRenderer.ts with
// `supportThemeIcons`, iconLabels.ts).
package tests.contrib;

import cityscape.contrib.hover.view.MarkdownRenderer;
import cityscape.contrib.hover.view.MarkdownThemeIcons;
import cityscape.contrib.hover.view.MarkdownThemeIcons.CodeSpanIcons;
import cityscape.contrib.hover.view.MarkdownThemeIcons.ThemeIconPlugin;
import markdown.Markdown as MdParser;
import markdown.ParseOptions as MdParseOptions;
import markdown.mdast.Node.Node as MdNode;
import markdown.mdast.NodeTools as MdNodeTools;
import testing.TestCase;

class HoverMarkdownTest extends TestCase {

    function parse(value:String, supportHtml:Bool = true):Array<HoverMarkdownBlock> {
        return MarkdownRenderer.parseHoverMarkdown({value: value, supportHtml: supportHtml}, 16);
    }

    function testBlocksAndMargins() {
        final blocks = parse('**Barista** (character)\n\n---\n\n**Fields**  \n<small>[friendship](#4,3): `0` (number)</small>\n\n- a\n- b\n\n1. one\n\n```js\nx\n```');
        assertEquals(([HoverMarkdownBlockKind.Paragraph, HoverMarkdownBlockKind.Rule, HoverMarkdownBlockKind.Paragraph, HoverMarkdownBlockKind.UnorderedList, HoverMarkdownBlockKind.OrderedList, HoverMarkdownBlockKind.Code] : Array<Int>).join(','), [for (b in blocks) (b.kind : Int)].join(','));
        // p: 8 above and below, none above the first
        assertEquals(0.0, blocks[0].marginTop);
        assertEquals(8.0, blocks[0].marginBottom);
        assertTrue(blocks[0].startsWithStrong);
        // hr: 4 above, -4 below, -8 on the sides (the hover's width)
        assertEquals(4.0, blocks[1].marginTop);
        assertEquals(-4.0, blocks[1].marginBottom);
        assertEquals(-8.0, blocks[1].marginLeft);
        assertEquals(-8.0, blocks[1].marginRight);
        // ol: 1em; .code last: none below
        assertEquals(16.0, blocks[4].marginTop);
        assertEquals(8.0, blocks[5].marginTop);
        assertEquals(0.0, blocks[5].marginBottom);
        // collapsed like CSS: max of the positive ones plus the most negative
        assertEquals(8.0, MarkdownRenderer.collapseMargins(blocks[0].marginBottom, blocks[1].marginTop));
        assertEquals(4.0, MarkdownRenderer.collapseMargins(blocks[1].marginBottom, blocks[2].marginTop));
        assertEquals(-2.0, MarkdownRenderer.collapseMargins(-4, 2));
    }

    function testSmallLines() {
        final blocks = parse('**Fields**  \n<small>[friendship](#4,3): `0` (number)</small>  \n<small>[greeted](#5,3): `false`</small>');
        assertEquals(1, blocks.length);
        final lines = blocks[0].lines;
        assertEquals(3, lines.length);
        assertEquals('**Fields**', lines[0].source);
        assertFalse(lines[0].small);
        assertEquals('[friendship](#4,3): `0` (number)', lines[1].source);
        assertTrue(lines[1].small);
        assertEquals('[greeted](#5,3): `false`', lines[2].source);
        assertTrue(lines[2].small);
        // small text within a line keeps the size of the paragraph
        final mixed = parse('Some <small>small</small> words');
        assertEquals(null, mixed[0].lines);
        assertEquals('Some small words', mixed[0].source);
    }

    function testHtml() {
        // the tags of Monaco's sanitizer
        assertEquals('a `0` b', parse('a <code>0</code> b')[0].source);
        assertEquals('x <b>bold</b> y', parse('x <b>bold</b> y')[0].source);
        assertEquals('red text', parse('<span style="color:#f00;">red</span> text')[0].source);
        final br = parse('one<br>two');
        assertEquals('one\\\ntwo', br[0].source);
        // without supportHtml, HTML shows as text
        assertEquals('x &lt;b&gt;bold&lt;/b&gt; y', parse('x <b>bold</b> y', false)[0].source);
        // code is left alone
        assertEquals('`<b>`', parse('`<b>`')[0].source);
    }

    /**
     * `$(name)` becomes a codicon (its `~modifier` dropped), outside code
     * blocks and code spans; `\$(name)` stays as text
     * (`markdownEscapeEscapedIcons`); what is not an icon name stays.
     */
    function testThemeIcons() {
        final icon = (name:String) -> '![](' + MarkdownThemeIcons.SCHEME + name + ')';
        assertEquals('Run ' + icon('play') + ' now', MarkdownThemeIcons.transform('Run $(play) now'));
        assertEquals(icon('zap') + icon('sync'), MarkdownThemeIcons.transform('$(zap)$(sync~spin)'));
        assertEquals('**' + icon('error') + ' bold**', MarkdownThemeIcons.transform('**$(error) bold**'));
        assertEquals('[' + icon('link') + ' open](http://x)', MarkdownThemeIcons.transform('[$(link) open](http://x)'));
        // an escaped backslash before the icon
        assertEquals('\\\\' + icon('play') + ' text', MarkdownThemeIcons.transform('\\\\$(play) text'));
        // escaped, in code, not a name
        for (same in ['\\$(play)', '`$(play)`', '```\n$(play)\n```', '$(not a name)', '$()', '$(a~)', '$(play', 'cost $5 (each)']) {
            assertEquals(same, MarkdownThemeIcons.transform(same), same);
        }
        // only with supportThemeIcons
        final blocks = MarkdownRenderer.parseHoverMarkdown({value: '$(zap) Run', supportThemeIcons: true}, 16);
        assertEquals(icon('zap') + ' Run', blocks[0].source);
        assertEquals('$(zap) Run', MarkdownRenderer.parseHoverMarkdown({value: '$(zap) Run'}, 16)[0].source);
    }

    /**
     * Monaco renders the codicons of code spans too (`renderLabelWithIcons`
     * over the whole HTML, markdownRenderer.ts: `<code><span class="codicon
     * codicon-zap"></span> run</code>` on the real Monaco 0.52.2); an
     * escaped `\$(zap)` in code stays text with its backslash. The plugin
     * takes the code spans with icons (`splitCodeSpan`) and leaves the
     * others to the text view.
     */
    function testThemeIconsInCodeSpans() {
        function parts(value:String):Null<String> {
            final p = MarkdownThemeIcons.splitCodeSpan(value);
            return p == null ? null : [for (x in p) x.icon != null ? '<' + x.icon + '>' : x.text].join('|');
        }
        assertEquals('<zap>| run', parts('$(zap) run'));
        assertEquals('a |<check>| b', parts('a $(check) b'));
        assertEquals('<zap>|<sync>', parts('$(zap)$(sync~spin)'));
        assertEquals('<a>|x|<b>', parts('$(a)x$(b)'));
        assertEquals(null, parts('no icon'));
        assertEquals(null, parts('\\$(zap) escaped'));
        assertEquals(null, parts('\\\\$(zap) escaped twice'));
        assertEquals(null, parts('$(not a name)'));
        assertEquals('<zap>|\\$(check)', parts('$(zap)\\$(check)'));
        // the plugin: a code span with icons becomes its node, one without
        // stays the text view's inline code; the text of the node is the code
        final plugin = new ThemeIconPlugin();
        function inlineCodeOf(markdown:String):MdNode {
            final root = MdParser.toMdast(markdown, MdParseOptions.gfm());
            final paragraph = MdNodeTools.children(root)[0];
            return MdNodeTools.children(paragraph)[0];
        }
        final withIcon = plugin.parse(inlineCodeOf('`$(zap) run`'), null);
        assertNotNull(withIcon);
        assertEquals('$(zap) run', withIcon.asText());
        assertEquals(2, (withIcon.data(CodeSpanIcons) : CodeSpanIcons).parts.length);
        assertEquals(null, plugin.parse(inlineCodeOf('`plain code`'), null));
        assertEquals(null, plugin.parse(inlineCodeOf('`\\$(zap)`'), null));
        // the source transform leaves the code spans alone (the plugin
        // renders them), so the escaped icon keeps its backslash in code
        assertEquals('`$(zap) run` and `\\$(zap)`', MarkdownThemeIcons.transform('`$(zap) run` and `\\$(zap)`'));
    }

}

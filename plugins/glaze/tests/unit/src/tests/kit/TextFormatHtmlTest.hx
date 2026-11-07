// Ported from gpui-kit 0.8.1: crates/base/src/text/format/html.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.DefiniteLength;
import gpui.base.text.BlockNode;
import gpui.base.text.ImageNode;
import gpui.base.text.InlineNode;
import gpui.base.text.NodeContext;
import gpui.base.text.Paragraph;
import gpui.base.text.ParsedDocument;
import gpui.base.text.format.HtmlFormat;
import testing.TestCase;

import gpui.Prelude.px;
import gpui.Prelude.relative;

/**
 * Tests of `gpui.base.text.format.HtmlFormat` (Rust `text/format/html.rs`).
 */
@:access(gpui.base.text)
@:access(gpui.base.text.format.HtmlFormat)
class TextFormatHtmlTest extends TestCase {

    static function blocksString(document:ParsedDocument):String {
        return Std.string(document.blocks);
    }

    static function lengthEq(a:Null<DefiniteLength>, b:Null<DefiniteLength>):Bool {
        return a == null ? b == null : b != null && a.equals(b);
    }

    function testCleanupHtml() {
        var html = "<p>
            and
            <code>code</code>
            text
        </p>";
        var cleaned = HtmlFormat.cleanupHtml(html);
        assertEquals("<p>and <code>code</code> text", cleaned.toString());

        html = "<p>
            and
            <em>   <code>code</code>   <i>italic</i>   </em>
            text
        </p>";
        cleaned = HtmlFormat.cleanupHtml(html);
        assertEquals("<p>and <em><code>code</code> <i>italic</i></em> text", cleaned.toString());
    }

    function testPreTextStaysText() {
        final cx = new NodeContext();
        for (c in [
            // Escaped markup is text, not elements.
            ["<pre>&lt;b&gt;bold&lt;/b&gt; &amp;amp;</pre>", "<b>bold</b> &amp;"],
            // Spaces, tabs and line feeds stay as they are.
            ["<pre>  one\n\n\ttwo  </pre>", "  one\n\n\ttwo  "],
            // The parser drops only the line feed right after `<pre>`.
            ["<pre>\none</pre>", "one"],
            ["<pre>\n\none</pre>", "\none"],
            // A comment is left out, and the line feed after it kept.
            ["<pre><!-- note -->\none</pre>", "\none"],
        ]) {
            final document = HtmlFormat.parse(c[0], cx);
            switch document.blocks[0] {
                case Paragraph(paragraph):
                    assertEquals(c[1], paragraph.text(), c[0]);
                case _:
                    fail('expected one paragraph, got ' + blocksString(document));
            }
        }
    }

    function testPreKeepsWhitespaceInNestedElements() {
        final cx = new NodeContext();
        for (c in [
            // Code in `<pre><code>` keeps its line feeds and indent.
            ["<pre><code>fn main() {\n    one();\n}</code></pre>", "fn main() {\n    one();\n}"],
            // So does text deeper down, and the space between elements.
            ["<pre><code><b>one</b>  <i>two\n\tthree</i></code></pre>", "one  two\n\tthree"],
            // The parser keeps a line feed after `<code>`, unlike `<pre>`.
            ["<pre><code>\none</code></pre>", "\none"],
            // Escaped markup is still text.
            ["<pre><code>&lt;b&gt; &amp;amp;</code></pre>", "<b> &amp;"],
            // Outside `<pre>`, whitespace is collapsed as before.
            ["<p><code>one\n   two</code></p>", "one two"],
        ]) {
            final document = HtmlFormat.parse(c[0], cx);
            switch document.blocks[0] {
                case Paragraph(paragraph):
                    assertEquals(c[1], paragraph.text(), c[0]);
                case _:
                    fail('expected one paragraph, got ' + blocksString(document));
            }
        }
    }

    function testTrimText() {
        assertEquals(" Hello world ", HtmlFormat.trimText("  \n\tHello world \t\r "));
    }

    function testMark() {
        final cx = new NodeContext();

        // `<mark>` is rendered as a highlight, kept as `==...==` in markdown.
        var html = '<p>Hello <mark>world</mark></p>';
        var node = HtmlFormat.parse(html, cx);
        assertEquals("Hello ==world==", node.toMarkdown());

        html = '<p><mark color="blue">blue</mark> and <mark style="background-color: #336699">hex</mark></p>';
        node = HtmlFormat.parse(html, cx);
        assertEquals("==blue== and ==hex==", node.toMarkdown());
    }

    function testKeepSpaces() {
        var html = '<p>and <code>code</code> text</p>';
        final cx = new NodeContext();
        var node = HtmlFormat.parse(html, cx);
        assertEquals("and `code` text", node.toMarkdown());

        html = '
            <div>
            <p>
                and
                <em>   <code>code</code>   <i>italic</i>   </em>
                text
            </p>
            <p>
                <img src="https://example.com/image.png" alt="Example" width="100" height="200" title="Example Image" />
            </p>
            <ul>
                <li>Item 1</li>
                <li>Item 2
                </li>
            </ul>
            </div>
        ';
        node = HtmlFormat.parse(html, cx);
        assertEquals('and *code italic* text\n\n![Example](https://example.com/image.png "Example Image")\n\n- Item 1\n- Item 2', node.toMarkdown());
    }

    /** The text of the one paragraph `html` parses to. */
    function paragraphText(html:String):String {
        final cx = new NodeContext();
        final document = HtmlFormat.parse(html, cx);
        return switch document.blocks[0] {
            case Paragraph(paragraph): paragraph.text();
            case _:
                fail('expected one paragraph, got ' + blocksString(document));
                null;
        }
    }

    function testBrBreaksTheLineWhereItStands() {
        assertEquals("one\ntwo", paragraphText("<p>one<br>two</p>"));
        assertEquals("one\ntwo\n\nthree", paragraphText("one<br>two<br><br>three"));
        assertEquals("one\ntwo", paragraphText("<b>one<br>two</b>"));
        // The minifier trims the spaces around it.
        assertEquals("one\ntwo", paragraphText("<p>one <br> two</p>"));
        // As in a browser, a break that ends a block adds no line.
        assertEquals("one", paragraphText("<p>one<br></p>"));
        assertEquals("one\n", paragraphText("<p>one<br><br></p>"));
        // Markdown parses inline HTML one tag at a time and needs the break.
        assertEquals("\n", paragraphText("<br>"));
    }

    function testBrThatEndsInlineMarkup() {
        // Inside inline markup the break joins the text before it in one
        // run; at the end of the block it still adds no line.
        for (tag in ["b", "span"]) {
            assertEquals("one", paragraphText('<p><$tag>one<br></$tag></p>'), tag);
            assertEquals("one\n", paragraphText('<p><$tag>one<br><br></$tag></p>'), tag);
            assertEquals("one\ntwo", paragraphText('<p><$tag>one<br>two</$tag></p>'), tag);
        }
        assertEquals("one", paragraphText("<p>one<b><br></b></p>"));
        assertEquals("one\n", paragraphText("<p><b>one<br></b><br></p>"));

        // The marks end with the text they kept.
        final cx = new NodeContext();
        final document = HtmlFormat.parse("<p><b>one<br></b></p>", cx);
        switch document.blocks[0] {
            case Paragraph(paragraph):
                final children = paragraph.children_;
                if (children.length != 1) {
                    fail('expected one node, got ' + children.length);
                    return;
                }
                final node = children[0];
                var all = true;
                var anyBold = false;
                for (m in node.marks_) {
                    if (m.range.start != 0 || m.range.end != 3)
                        all = false;
                    if (m.mark.bold)
                        anyBold = true;
                }
                assertTrue(all);
                assertTrue(anyBold);
            case _:
                fail('expected one paragraph, got ' + blocksString(document));
        }
    }

    function testLiteralTrailingLineFeedsArePreserved() {
        for (c in [
            ["<pre>one\n</pre>", "one\n"],
            ["<pre>one\n\n</pre>", "one\n\n"],
            ["<pre>one\n<br></pre>", "one\n"],
            ["<pre>one<br>\n</pre>", "one\n\n"],
            ["<textarea>one\n</textarea>", "one\n"],
        ]) {
            assertEquals(c[1], paragraphText(c[0]), c[0]);
        }
    }

    function testTrailingBreaksAtTextBlockBoundaries() {
        for (tag in ["p", "h1", "h6", "td", "th", "li"]) {
            for (c in [
                ["one<br>", "one"],
                ["one<br><br>", "one\n"],
                ["<b>one<br></b>", "one"],
                ["<span>one<br><br></span>", "one\n"],
                ["one<br>two", "one\ntwo"],
                ["one<br><span></span>", "one"],
            ]) {
                final content = c[0];
                final expected = c[1];
                final html = switch tag {
                    case "td" | "th": '<table><tr><$tag>$content</$tag></tr></table>';
                    case "li": '<ul><li>$content</li></ul>';
                    case _: '<$tag>$content</$tag>';
                }
                final cx = new NodeContext();
                final document = HtmlFormat.parse(html, cx);
                final paragraph:Null<Paragraph> = switch document.blocks[0] {
                    case Paragraph(paragraph) | Heading(_, paragraph, _): paragraph;
                    case Table(table): table.children[0].children[0].children;
                    case List(children, _, _, _):
                        switch children[0] {
                            case ListItem(children, _, _, _):
                                if (children.length == 1) {
                                    switch children[0] {
                                        case Paragraph(paragraph): paragraph;
                                        case _: null;
                                    }
                                }
                                else {
                                    null;
                                }
                            case _: null;
                        }
                    case _: null;
                }
                if (paragraph == null) {
                    fail('expected text block: $html');
                    continue;
                }
                assertEquals(expected, paragraph.text(), html);
                for (node in paragraph.children_) {
                    var inside = true;
                    for (m in node.marks_) {
                        if (!(m.range.start < m.range.end && m.range.end <= gpui.base.text.TextUtils.len(node.text_)))
                            inside = false;
                    }
                    assertTrue(inside, 'mark outside text: $html');
                }
            }
        }
    }

    function testValueToLength() {
        assertTrue(lengthEq(px(100.).toDefiniteLength(), HtmlFormat.valueToLength("100px")));
        assertTrue(lengthEq(relative(1.), HtmlFormat.valueToLength("100%")));
        assertTrue(lengthEq(relative(0.56), HtmlFormat.valueToLength("56%")));
        assertTrue(lengthEq(px(240.).toDefiniteLength(), HtmlFormat.valueToLength("240")));
    }

    function testImage() {
        var html = '<img src="https://example.com/image.png" alt="Example" width="100" height="200" title="Example Image" />';
        final cx = new NodeContext();
        var node = HtmlFormat.parse(html, cx);
        var image = new ImageNode("https://example.com/image.png");
        image.alt = "Example";
        image.width = px(100.).toDefiniteLength();
        image.height = px(200.).toDefiniteLength();
        image.title = "Example Image";
        var paragraph = new Paragraph();
        paragraph.children_ = [InlineNode.ofImage(image)];
        assertTrue(node.equals(new ParsedDocument(html, [BlockNode.Paragraph(paragraph)])), blocksString(node));

        html = '<img src="https://example.com/image.png" alt="Example" style="width: 80%" title="Example Image" />';
        node = HtmlFormat.parse(html, cx);
        image = new ImageNode("https://example.com/image.png");
        image.alt = "Example";
        image.width = relative(0.8);
        image.height = null;
        image.title = "Example Image";
        paragraph = new Paragraph();
        paragraph.children_ = [InlineNode.ofImage(image)];
        assertTrue(node.equals(new ParsedDocument(html, [BlockNode.Paragraph(paragraph)])), blocksString(node));
    }

}

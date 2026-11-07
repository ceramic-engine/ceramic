// Ported from gpui-kit 0.8.1: crates/base/src/text/format/markdown.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AbsoluteLength;
import glaze.App;
import glaze.DefiniteLength;
import glaze.Hsla;
import glaze.ImageSource;
import glaze.IntoElement;
import glaze.Range;
import glaze.Rgba;
import glaze.Window;
import glaze.kit.base.input.Selection;
import glaze.kit.base.text.BlockNode;
import glaze.kit.base.text.CodeBlock;
import glaze.kit.base.text.MarkdownExtensions;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.MarkdownParseContext;
import glaze.kit.base.text.MarkdownPlugin;
import glaze.kit.base.text.NodeContext;
import glaze.kit.base.text.Paragraph;
import glaze.kit.base.text.ParsedDocument;
import glaze.kit.base.text.RangedMark;
import glaze.kit.base.text.SourceSegment;
import glaze.kit.base.text.Span;
import glaze.kit.base.text.TextMark;
import glaze.kit.base.text.TextUtils;
import glaze.kit.base.text.format.MarkdownFormat;
import haxe.io.Bytes;
import markdown.mdast.Node.Node;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.DefiniteLengthTools;

private class Ticker {

    public final symbol:String;

    public function new(symbol:String) {
        this.symbol = symbol;
    }

}

/** Rust `markdown_ext::TestInlinePlugin` (test fixture of markdown_ext.rs). */
private class TestInlinePlugin extends MarkdownPlugin {

    final name_:String;
    var parser:Null<(node:Node, cx:MarkdownParseContext) -> Null<MarkdownNode>> = null;

    public function new(name:String) {
        this.name_ = name;
    }

    public function parseWith(parser:(node:Node, cx:MarkdownParseContext) -> Null<MarkdownNode>):TestInlinePlugin {
        this.parser = parser;
        return this;
    }

    public function name():String {
        return name_;
    }

    public function parse(node:Node, cx:MarkdownParseContext):Null<MarkdownNode> {
        return parser != null ? parser(node, cx) : null;
    }

}

private class TickerPlugin extends MarkdownPlugin {

    final name_:String;

    public function new(name:String) {
        this.name_ = name;
    }

    override public function isBlock():Bool {
        return true;
    }

    public function name():String {
        return name_;
    }

    public function parse(node:Node, cx:MarkdownParseContext):Null<MarkdownNode> {
        return TextFormatMarkdownTest.parseTickerBlock(node, cx);
    }

    override public function render(node:MarkdownNode, window:Window, cx:App):IntoElement {
        return div().child(node.asText());
    }

}

/**
 * Tests of `glaze.kit.base.text.format.MarkdownFormat` (Rust `text/format/markdown.rs`).
 */
@:access(glaze.kit.base.text)
@:access(glaze.kit.base.text.format.MarkdownFormat)
class TextFormatMarkdownTest extends TestCase {

    // Helpers

    static function parse(source:String, cx:NodeContext):ParsedDocument {
        return MarkdownFormat.parse(source, cx);
    }

    static function firstParagraph(block:BlockNode):Null<Paragraph> {
        return switch block {
            case Paragraph(paragraph) | Heading(_, paragraph, _): paragraph;
            case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                findMap(children, firstParagraph);
            case _: null;
        }
    }

    static function firstCodeBlock(block:BlockNode):Null<CodeBlock> {
        return switch block {
            case CodeBlock(code): code;
            case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                findMap(children, firstCodeBlock);
            case _: null;
        }
    }

    static function findMap<T>(blocks:Array<BlockNode>, f:(BlockNode) -> Null<T>):Null<T> {
        for (block in blocks) {
            final found = f(block);
            if (found != null)
                return found;
        }
        return null;
    }

    static function r(start:Int, end:Int):Range {
        return new Range(start, end);
    }

    static function seg(renderedStart:Int, renderedEnd:Int, sourceStart:Int, sourceEnd:Int, linear:Bool):SourceSegment {
        return new SourceSegment(r(renderedStart, renderedEnd), r(sourceStart, sourceEnd), linear);
    }

    static function aligned(raw:String, rendered:String, sourceOffset:Int, decodeEntities:Bool, decodeEscapes:Bool):Array<SourceSegment> {
        return MarkdownFormat.alignedSourceSegments(Bytes.ofString(raw), Bytes.ofString(rendered), sourceOffset, decodeEntities, decodeEscapes);
    }

    function assertRange(expected:Null<Range>, actual:Null<Range>, ?message:String, ?pos:haxe.PosInfos) {
        assertEquals(Range.describe(expected), Range.describe(actual), message, pos);
    }

    function assertSegments(expected:Array<SourceSegment>, actual:Array<SourceSegment>, ?pos:haxe.PosInfos) {
        assertEquals(expected.map(s -> s.toString()).join('\n'), actual.map(s -> s.toString()).join('\n'), null, pos);
    }

    static function selectedRenderedRange(source:String, selection:Range):Null<Range> {
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = findMap(document.blocks, firstParagraph);
        if (paragraph == null)
            throw 'expected paragraph';
        final rendered = paragraph.text();
        final state = paragraph.state;
        state.setText(rendered);
        state.selection = Selection.fromRange(selection);
        return document.selectedSourceRange();
    }

    function selectRenderedRange(source:String, selection:Range):Range {
        final range = selectedRenderedRange(source, selection);
        assertNotNull(range, 'source range');
        return range;
    }

    static function selectedCodeRange(source:String, selection:Range):Null<Range> {
        final cx = new NodeContext();
        final document = parse(source, cx);
        final code = findMap(document.blocks, firstCodeBlock);
        if (code == null)
            throw 'expected code block';
        code.setSelection(selection);
        return document.selectedSourceRange();
    }

    static function mdxContext():NodeContext {
        final cx = new NodeContext();
        cx.markdownExtensions = new MarkdownExtensions().mdx();
        return cx;
    }

    static function selectedMdxRenderedRange(source:String, selection:Range):Null<Range> {
        final document = parse(source, mdxContext());
        final paragraph = findMap(document.blocks, firstParagraph);
        if (paragraph == null)
            throw 'expected MDX paragraph';
        final rendered = paragraph.text();
        paragraph.state.setText(rendered);
        paragraph.state.selection = Selection.fromRange(selection);
        return document.selectedSourceRange();
    }

    static function selectedMdxCode(source:String, selectedText:String):Null<Range> {
        final document = parse(source, mdxContext());
        final code = findMap(document.blocks, firstCodeBlock);
        if (code == null)
            throw 'expected MDX code block';
        final codeText = code.code();
        final index = codeText.indexOf(selectedText);
        if (index == -1)
            throw 'selected MDX code';
        final start = TextUtils.len(codeText.substr(0, index));
        code.setSelection(r(start, start + TextUtils.len(selectedText)));
        return document.selectedSourceRange();
    }

    static function paragraphAt(document:ParsedDocument, ix:Int):Paragraph {
        return switch document.blocks[ix] {
            case Paragraph(paragraph): paragraph;
            case _: throw 'expected paragraph';
        }
    }

    static function codeBlockAt(document:ParsedDocument, ix:Int):CodeBlock {
        return switch document.blocks[ix] {
            case CodeBlock(code): code;
            case _: throw 'expected code block';
        }
    }

    static function markedRuns(paragraph:Paragraph, predicate:(TextMark) -> Bool):Array<String> {
        final runs = [];
        for (node in paragraph.children_) {
            for (ranged in node.marks_) {
                if (predicate(ranged.mark))
                    runs.push(TextUtils.slice(node.text_, ranged.range.start, ranged.range.end));
            }
        }
        return runs;
    }

    static function boldRuns(paragraph:Paragraph):Array<String> {
        return markedRuns(paragraph, mark -> mark.bold);
    }

    static function highlightRuns(paragraph:Paragraph):Array<{text:String, color:Hsla}> {
        final runs = [];
        for (node in paragraph.children_) {
            for (ranged in node.marks_) {
                if (ranged.mark.highlight != null)
                    runs.push({text: TextUtils.slice(node.text_, ranged.range.start, ranged.range.end), color: ranged.mark.highlight});
            }
        }
        return runs;
    }

    static function sourceOf(cx:MarkdownParseContext, node:Node):String {
        final source = cx.nodeSource(node);
        return source != null ? source : '';
    }

    @:allow(tests.kit)
    static function parseTickerBlock(node:Node, cx:MarkdownParseContext):Null<MarkdownNode> {
        final paragraph = switch node {
            case Paragraph(paragraph): paragraph;
            case _: return null;
        }
        if (paragraph.children.length != 1)
            return null;
        final text = switch paragraph.children[0] {
            case Text(text): text;
            case _: return null;
        }
        if (!StringTools.startsWith(text.value, '$'))
            return null;
        final symbol = text.value.substr(1);
        final nodeText = "$" + symbol;

        return new MarkdownNode('ticker', new Ticker(symbol)).text(nodeText).markdown(sourceOf(cx, node));
    }

    static function contextWith(extensions:MarkdownExtensions):NodeContext {
        final cx = new NodeContext();
        cx.markdownExtensions = extensions;
        return cx;
    }

    // Tests

    function testTableRowsKeepMissingCellsImplicit() {
        final cx = new NodeContext();
        final document = parse("| A | B | C |\n| --- | --- | --- |\n| one |\n| two | three | four | ignored |\n| five | | six |\n", cx);
        final table = switch document.blocks[0] {
            case Table(table): table;
            case _: throw 'expected table';
        }
        assertEquals(3, table.columnAligns_.length);
        assertEquals('3,1,3,3', [for (row in table.children) row.children.length].join(','));
        assertEquals('one', table.children[1].children[0].children.text());
        assertEquals('four', table.children[2].children[2].children.text());
        assertEquals('', table.children[3].children[1].children.text());
        assertEquals('six', table.children[3].children[2].children.text());
    }

    function testSparseTableCellCountTracksSourceCells() {
        for (pair in [[32, 64], [64, 128]]) {
            final columns = pair[0];
            final rows = pair[1];
            final source = TextUtils.repeat('|h', columns) + '|\n' + TextUtils.repeat('|---', columns) + '|\n' + TextUtils.repeat('|x|\n', rows);
            final cx = new NodeContext();
            final document = parse(source, cx);
            final table = switch document.blocks[0] {
                case Table(table): table;
                case _: throw 'expected table';
            }
            assertEquals(columns, table.columnAligns_.length);
            assertEquals(rows + 1, table.children.length);
            assertEquals(columns, table.children[0].children.length);
            var allOne = true;
            for (i in 1...table.children.length) {
                if (table.children[i].children.length != 1)
                    allOne = false;
            }
            assertTrue(allOne);
            var sum = 0;
            for (row in table.children)
                sum += row.children.length;
            assertEquals(columns + rows, sum);
        }
    }

    function testSelectedSourceRangeUsesTheSelectedIdenticalStyledOccurrence() {
        final source = "**same** then **same**";
        assertRange(r(16, 20), selectRenderedRange(source, r(10, 14)));
    }

    function testSelectedSourceRangeMapsPartialStyledText() {
        final source = "**same** then **same**";
        assertRange(r(17, 19), selectRenderedRange(source, r(11, 13)));
    }

    function testSourceSegmentsCompactContiguousOneToOneMappings() {
        final source = "plain text";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = firstParagraph(document.blocks[0]);
        assertSegments([seg(0, source.length, 0, source.length, true)], paragraph.children_[0].sourceSegments_);

        assertRange(r(2, 7), selectRenderedRange(source, r(2, 7)));
    }

    function testSourceAlignmentCompactsLongWhitespaceRuns() {
        for (raw in [
            TextUtils.repeat("a ", 16384),
            "a" + TextUtils.repeat(" ", 32768) + "b",
            "a" + TextUtils.repeat(" \t", 16384) + "b\n",
        ]) {
            final segments = aligned(raw, raw, 7, true, true);
            // Rust also checks `segments.capacity() < 64` (no per-character
            // allocation retained): Rust only, the single segment covers it.
            assertSegments([seg(0, raw.length, 7, 7 + raw.length, true)], segments);
        }
    }

    function testSourceAlignmentPreservesMultilineCodeAndFinalNewline() {
        final raw = TextUtils.repeat("x\n", 16384);
        final rendered = raw.substr(0, raw.length - 1);
        assertSegments([seg(0, rendered.length, 4, 4 + rendered.length, true)], aligned(raw, rendered, 4, false, false));
        assertSegments([seg(0, 2, 0, 2, true), seg(2, 3, 2, 5, false)], aligned("a\n> \n", "a\n\n", 0, false, false));
    }

    function testSourceAlignmentKeepsSoftBreaksAndEntitiesAtomic() {
        assertSegments([seg(0, 1, 9, 10, true), seg(1, 2, 11, 13, false), seg(2, 3, 13, 14, true)], aligned("a \r\nb", "a b", 9, true, true));
        final entity = "&NotEqualTilde;";
        final decoded = "≂̸";
        assertSegments([seg(0, TextUtils.len(decoded), 3, 3 + entity.length, false)], aligned(entity, decoded, 3, true, true));
    }

    function testSourceAlignmentResumesAfterUnmappedCharacters() {
        final raw = TextUtils.repeat("abc", 4096);
        final rawBytes = Bytes.ofString(raw);
        final positions = new SourceCharPositions();
        assertEquals(1, MarkdownFormat.sourceCharOffset(rawBytes, 0, 'b'.code, positions));
        assertTrue(positions.index == null, "successful scans need no index");
        assertEquals(-1, MarkdownFormat.sourceCharOffset(rawBytes, 0, 0xFFFD, positions));
        assertTrue(positions.index != null, "failed scans must not be repeated");
        assertEquals(4, MarkdownFormat.sourceCharOffset(rawBytes, 2, 'b'.code, positions));
        assertEquals(-1, MarkdownFormat.sourceCharOffset(rawBytes, raw.length, 'a'.code, positions));

        final missing = TextUtils.repeat("�", 4096);
        final missingLen = TextUtils.len(missing);
        assertSegments([seg(missingLen, missingLen + 3, 5, 8, true)], aligned(raw, missing + "abc", 5, true, true));
        assertSegments([seg(missingLen, missingLen + 1, 0, 5, false), seg(missingLen + 1, missingLen + 2, 5, 6, true)],
            aligned("&amp;z", missing + "&z", 0, true, true));
    }

    function testSourceAlignmentParsesLongTextAndCodeWithoutSelection() {
        final source = TextUtils.repeat("a ", 4096) + "end";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = firstParagraph(document.blocks[0]);
        assertEquals(source, paragraph.text());
        final segments = paragraph.children_[0].sourceSegments_;
        assertEquals(1, segments.length);
        assertRange(r(0, source.length), segments[0].source);
        assertRange(r(source.length - 3, source.length), selectedRenderedRange(source, r(source.length - 3, source.length)));

        final body = TextUtils.repeat("x\n", 4096);
        final source = "```\n" + body + "```";
        final document = parse(source, cx);
        assertNotNull(firstCodeBlock(document.blocks[0]));
        assertRange(r(body.length + 2, body.length + 3), selectedCodeRange(source, r(body.length - 2, body.length - 1)));
    }

    function testSourceSegmentsKeepNonLinearMappingsAtomic() {
        final source = "a\\* &amp; b";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = firstParagraph(document.blocks[0]);
        final segments = paragraph.children_[0].sourceSegments_;

        assertTrue(segments.length < paragraph.children_[0].text_.length, "ordinary characters should be compacted into runs");
        inline function contains(expected:SourceSegment):Bool {
            return Lambda.exists(segments, s -> s.equals(expected));
        }
        assertTrue(contains(seg(1, 2, 1, 3, false)));
        assertTrue(contains(seg(3, 4, 4, 9, false)));

        assertRange(r(1, 3), selectRenderedRange(source, r(1, 2)));
        assertRange(r(4, 9), selectRenderedRange(source, r(3, 4)));
    }

    function testSourceSegmentsKeepAnEntityAsLongAsItsCharactersAtomic() {
        // `&acE;` decodes to `∾̳`: five bytes each, but not one for one.
        final source = "a &acE; b";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = firstParagraph(document.blocks[0]);
        assertEquals("a ∾̳ b", paragraph.children_[0].text_);
        assertSegments([seg(0, 2, 0, 2, true), seg(2, 7, 2, 7, false), seg(7, 9, 7, 9, true)], paragraph.children_[0].sourceSegments_);
        // Selecting the combining mark alone reports the whole entity.
        assertRange(r(2, 7), selectRenderedRange(source, r(5, 7)));
    }

    function testSelectedSourceRangeCrossesStyleBoundaries() {
        final source = "left **bold** right";
        assertRange(r(2, 16), selectRenderedRange(source, r(2, 12)));
    }

    function testSelectedSourceRangeMapsInlineCodeInMergedStyledNode() {
        final source = "**left `code` right**";
        assertRange(r(8, 12), selectedRenderedRange(source, r(5, 9)));
    }

    function testSelectedSourceRangeMapsInlineCodeDelimitersAndBoundaries() {
        final source = "`code` x";
        assertRange(r(1, 5), selectedRenderedRange(source, r(0, 4)));
        assertRange(r(7, 8), selectedRenderedRange(source, r(5, 6)));
        assertRange(r(4, 8), selectedRenderedRange(source, r(3, 6)));

        final padded = "`` code ` value ``";
        assertRange(r(3, 7), selectedRenderedRange(padded, r(0, 4)));
        assertRange(r(8, 9), selectedRenderedRange(padded, r(5, 6)));

        final literalEntity = "`&amp;`";
        assertRange(r(1, 6), selectedRenderedRange(literalEntity, r(0, 5)));
    }

    function testSelectedSourceRangeKeepsInlineCodeEscapesLiteral() {
        assertRange(r(2, 3), selectRenderedRange("`a\\\\b`", r(1, 2)));
        assertRange(r(3, 4), selectRenderedRange("`a\\\\b`", r(2, 3)));
        assertRange(r(2, 3), selectRenderedRange("`a\\*b`", r(1, 2)));
        assertRange(r(3, 4), selectRenderedRange("`a\\*b`", r(2, 3)));
        // The same punctuation is still an escape outside code.
        assertRange(r(1, 3), selectRenderedRange("a\\*b", r(1, 2)));
    }

    function testSelectedSourceRangeMapsFootnoteReferenceSyntax() {
        final source = "before[^note] after\n\n[^note]: body";
        assertRange(r(0, 6), selectedRenderedRange(source, r(0, 6)));
        assertRange(r(6, 13), selectedRenderedRange(source, r(6, 12)));
        assertRange(r(14, 19), selectedRenderedRange(source, r(13, 18)));
        assertRange(r(4, 16), selectedRenderedRange(source, r(4, 15)));
    }

    function testSelectedSourceRangeMapsMdxTextExpressionBody() {
        final source = "before {value + 1} after";
        assertRange(r(8, 17), selectedMdxRenderedRange(source, r(7, 16)));
        assertRange(r(4, 21), selectedMdxRenderedRange(source, r(4, 19)));
    }

    function testSelectedSourceRangeMapsMdxFlowExpressionBody() {
        final source = "{\n  value + 1\n}";
        assertRange(r(4, 13), selectedMdxCode(source, "value + 1"));
        assertRange(r(6, 11), selectedMdxCode(source, "lue +"));
    }

    function testSelectedSourceRangeMapsMathBlockBody() {
        final source = "$$\nx + y\n$$";
        assertRange(r(3, 8), selectedCodeRange(source, r(0, 5)));
        assertRange(r(5, 6), selectedCodeRange(source, r(2, 3)));
    }

    function testSelectedSourceRangeRejectsMappedBlockPlusUnmappableEntity() {
        final source = "mapped\n\nA &amp; B";
        final cx = new NodeContext();
        final document = parse(source, cx);
        assertEquals(2, document.blocks.length);
        final mapped = paragraphAt(document, 0);
        final entity = paragraphAt(document, 1);
        mapped.state.selection = Selection.fromRange(r(0, 6));

        entity.state.selection = Selection.fromRange(r(2, 2));
        assertRange(r(0, 6), document.selectedSourceRange());

        entity.state.selection = Selection.fromRange(r(2, 3));
        assertRange(r(0, 15), document.selectedSourceRange());
    }

    function testSelectedSourceRangeMapsFencedCodeBodyAfterMatchingInfoString() {
        final source = "```rust\nrust\n```";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final code = codeBlockAt(document, 0);
        code.setSelection(r(0, 4));

        assertRange(r(8, 12), document.selectedSourceRange());
    }

    function testSelectedSourceRangeMapsEachLiteralBackslashInFencedCode() {
        final source = "```\na\\\\b\n```";
        assertRange(r(5, 6), selectedCodeRange(source, r(1, 2)));
        assertRange(r(6, 7), selectedCodeRange(source, r(2, 3)));
        assertRange(r(5, 7), selectedCodeRange(source, r(1, 3)));
        final punctuation = "```\na\\*b\n```";
        assertRange(r(5, 6), selectedCodeRange(punctuation, r(1, 2)));
        assertRange(r(6, 7), selectedCodeRange(punctuation, r(2, 3)));
        assertRange(r(5, 7), selectedCodeRange("```\na\\\\b\r\n```", r(1, 3)));
        final multiline = "```\na\\\\\nb\n```";
        assertRange(r(5, 6), selectedCodeRange(multiline, r(1, 2)));
        assertRange(r(6, 7), selectedCodeRange(multiline, r(2, 3)));
        assertRange(r(7, 8), selectedCodeRange(multiline, r(3, 4)));
        assertRange(r(8, 9), selectedCodeRange(multiline, r(4, 5)));
    }

    function testSelectedSourceRangeExcludesClosingFenceCandidate() {
        final source = "````text\n```\n````";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final code = codeBlockAt(document, 0);
        code.setSelection(r(0, 3));

        assertRange(r(9, 12), document.selectedSourceRange());
    }

    function testSelectedSourceRangeMapsIndentedCodeContent() {
        final source = "    rust";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final code = codeBlockAt(document, 0);
        code.setSelection(r(0, 4));

        assertRange(r(4, 8), document.selectedSourceRange());
    }

    function testSelectedSourceRangeMapsMultilineIndentedCode() {
        final source = "    one\n    two\n    three";
        assertRange(r(4, 7), selectedCodeRange(source, r(0, 3)));
        assertRange(r(12, 15), selectedCodeRange(source, r(4, 7)));
        assertRange(r(4, 25), selectedCodeRange(source, r(0, 13)));
    }

    function testSelectedSourceRangeMapsLiteralBackslashesInIndentedCode() {
        final source = "    one\n    a\\\\b";
        assertRange(r(13, 14), selectedCodeRange(source, r(5, 6)));
        assertRange(r(14, 15), selectedCodeRange(source, r(6, 7)));
        assertRange(r(13, 15), selectedCodeRange(source, r(5, 7)));
    }

    function testSelectedSourceRangeMapsFencedCodeNestedInAList() {
        final source = "- ```rust\n  one\n  two\n  ```";
        assertRange(r(12, 15), selectedCodeRange(source, r(0, 3)));
        assertRange(r(18, 21), selectedCodeRange(source, r(4, 7)));
        assertRange(r(12, 21), selectedCodeRange(source, r(0, 7)));
    }

    function testSelectedSourceRangeMapsLiteralBackslashesInNestedFences() {
        for (source in ["- ```\n  a\\\\b\n  ```", "> ```\n> a\\\\b\n> ```"]) {
            assertRange(r(9, 10), selectedCodeRange(source, r(1, 2)));
            assertRange(r(10, 11), selectedCodeRange(source, r(2, 3)));
        }
    }

    function testSelectedSourceRangeMapsFencedCodeNestedInABlockquote() {
        final source = "> ```\n> one\n> two\n> ```";
        assertRange(r(8, 11), selectedCodeRange(source, r(0, 3)));
        assertRange(r(14, 17), selectedCodeRange(source, r(4, 7)));
        assertRange(r(8, 17), selectedCodeRange(source, r(0, 7)));
    }

    function testSelectedSourceRangeMapsFencedCodeWithBlankLinesAndRepeatedText() {
        final source = "```\nsame\n\nsame\n```";
        assertRange(r(4, 8), selectedCodeRange(source, r(0, 4)));
        assertRange(r(10, 14), selectedCodeRange(source, r(6, 10)));
        assertRange(r(4, 14), selectedCodeRange(source, r(0, 10)));
    }

    function testSelectedSourceRangeMapsTheWholeMarkdownEscape() {
        assertRange(r(0, 2), selectedRenderedRange("\\*", r(0, 1)));
    }

    function testSelectedSourceRangeMapsTextAfterAnEscapeCharacterForCharacter() {
        final source = "\\*abc";
        assertRange(r(0, 2), selectRenderedRange(source, r(0, 1)));
        assertRange(r(3, 4), selectRenderedRange(source, r(2, 3)));
        assertRange(r(0, 3), selectRenderedRange(source, r(0, 2)));
        // Only punctuation escapes, so a backslash before a letter is text.
        final source = "\\été";
        assertRange(r(0, 1), selectRenderedRange(source, r(0, 1)));
        assertRange(r(1, 3), selectRenderedRange(source, r(1, 3)));
    }

    function testSelectedSourceRangeMapsAfterAnEscapedBackslash() {
        final source = "a\\\\b";
        assertRange(r(1, 3), selectRenderedRange(source, r(1, 2)));
        assertRange(r(3, 4), selectRenderedRange(source, r(2, 3)));
        assertRange(r(1, 4), selectRenderedRange(source, r(1, 3)));

        final repeated = "\\\\\\\\b";
        assertRange(r(4, 5), selectRenderedRange(repeated, r(2, 3)));
    }

    function testSelectedSourceRangeDoesNotBorrowAnEscapeFromThePreviousNode() {
        final source = "a\\\\$x$";
        assertRange(r(3, 4), selectRenderedRange(source, r(2, 3)));
        assertRange(r(1, 4), selectRenderedRange(source, r(1, 3)));
    }

    function testSelectedSourceRangeDoesNotShiftAHardBreakAfterAnEscape() {
        final source = "a\\\\  \nb";
        assertRange(r(3, 6), selectRenderedRange(source, r(2, 3)));
        assertRange(r(1, 6), selectRenderedRange(source, r(1, 3)));
    }

    function testSelectedSourceRangeIncludesATrailingInlineImage() {
        final source = "before ![alt](image.png)";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = paragraphAt(document, 0);
        final image = Lambda.find(paragraph.children_, child -> child.image != null);
        assertNotNull(image, "expected image");
        image.state.setText("before ");
        image.state.selection = Selection.fromRange(r(0, 7));

        assertRange(r(0, source.length), document.selectedSourceRange());
    }

    function testSelectedSourceRangeIncludesALeadingInlineImage() {
        final source = "![alt](image.png) after";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = paragraphAt(document, 0);
        paragraph.state.setText(" after");
        paragraph.state.selection = Selection.fromRange(r(0, 6));

        assertRange(r(0, source.length), document.selectedSourceRange());
    }

    function testSelectedSourceRangeIncludesAnEnclosedInlineImage() {
        final source = "before ![alt](image.png) after";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = paragraphAt(document, 0);
        final image = Lambda.find(paragraph.children_, child -> child.image != null);
        assertNotNull(image, "expected image");
        image.state.setText("before ");
        image.state.selection = Selection.fromRange(r(0, 7));
        paragraph.state.setText(" after");
        paragraph.state.selection = Selection.fromRange(r(0, 6));

        assertRange(r(0, source.length), document.selectedSourceRange());
    }

    function testSelectedSourceRangeExcludesAnUnreachedInlineImage() {
        final source = "before ![alt](image.png) after";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = paragraphAt(document, 0);
        final image = Lambda.find(paragraph.children_, child -> child.image != null);
        assertNotNull(image, "expected image");
        image.state.setText("before ");
        image.state.selection = Selection.fromRange(r(0, 3));

        assertRange(r(0, 3), document.selectedSourceRange());

        image.state.selection = null;
        final afterStart = source.indexOf("after");
        paragraph.state.setText(" after");
        paragraph.state.selection = Selection.fromRange(r(2, 6));

        assertRange(r(afterStart + 1, source.length), document.selectedSourceRange());
    }

    function testSelectedSourceRangeIncludesConsecutiveInlineImages() {
        final source = "![first](one.png)![second](two.png) after";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = paragraphAt(document, 0);
        paragraph.state.setText(" after");
        paragraph.state.selection = Selection.fromRange(r(0, 6));

        assertRange(r(0, source.length), document.selectedSourceRange());
    }

    function testSelectedSourceRangeMapsDecodedEntityToItsSourceSyntax() {
        final source = "A &amp; B";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final paragraph = paragraphAt(document, 0);
        assertEquals("A & B", paragraph.text());

        assertRange(r(2, 7), selectedRenderedRange(source, r(2, 3)));
    }

    function testSelectedSourceRangeMapsAroundNamedAndNumericEntities() {
        final source = "Copyright &copy; &#x1F600; &#169; 2024";
        assertRange(r(0, 9), selectedRenderedRange(source, r(0, 9)));
        assertRange(r(10, 16), selectedRenderedRange(source, r(10, 12)));
        assertRange(r(17, 26), selectedRenderedRange(source, r(13, 17)));
        assertRange(r(27, 33), selectedRenderedRange(source, r(18, 20)));
        assertRange(r(34, 38), selectedRenderedRange(source, r(21, 25)));
        assertRange(r(8, 35), selectedRenderedRange(source, r(8, 22)));
    }

    function testSelectedSourceRangeMapsSoftBreaksWithSourcePrefixes() {
        assertRange(r(0, 1), selectedRenderedRange("a\n   b", r(0, 1)));
        assertRange(r(5, 6), selectedRenderedRange("a\n   b", r(2, 3)));
        assertRange(r(0, 6), selectedRenderedRange("a\n   b", r(0, 3)));

        assertRange(r(2, 3), selectedRenderedRange("> a\n> b", r(0, 1)));
        assertRange(r(6, 7), selectedRenderedRange("> a\n> b", r(2, 3)));
        assertRange(r(2, 7), selectedRenderedRange("> a\n> b", r(0, 3)));

        assertRange(r(2, 3), selectedRenderedRange("- a\n  b", r(0, 1)));
        assertRange(r(6, 7), selectedRenderedRange("- a\n  b", r(2, 3)));
        assertRange(r(2, 7), selectedRenderedRange("- a\n  b", r(0, 3)));
    }

    function testSelectedSourceRangeMapsSoftBreaksWithTrailingSpacesAndCrlf() {
        assertRange(r(0, 1), selectedRenderedRange("a \nb", r(0, 1)));
        assertRange(r(2, 3), selectedRenderedRange("a \nb", r(1, 2)));
        assertRange(r(3, 4), selectedRenderedRange("a \nb", r(2, 3)));
        assertRange(r(0, 4), selectedRenderedRange("a \nb", r(0, 3)));

        assertRange(r(2, 4), selectedRenderedRange("a \r\nb", r(1, 2)));
        assertRange(r(4, 5), selectedRenderedRange("a \r\nb", r(2, 3)));

        assertRange(r(0, 1), selectedRenderedRange("a\r\nb", r(0, 1)));
        assertRange(r(3, 4), selectedRenderedRange("a\r\nb", r(2, 3)));
        assertRange(r(0, 4), selectedRenderedRange("a\r\nb", r(0, 3)));
    }

    function testNestedEmphasisMergesTextMarks() {
        final cx = new NodeContext();
        final document = parse("This has **_bold and italic_** text.", cx);

        final paragraph = paragraphAt(document, 0);

        final boldItalic = Lambda.find(paragraph.children_, child -> child.text_ == "bold and italic");
        assertNotNull(boldItalic, "expected emphasized text");

        assertTrue(Lambda.exists(boldItalic.marks_, ranged -> ranged.mark.bold && ranged.mark.italic),
            "nested emphasis should produce a bold and italic mark");
    }

    function testReferenceImages() {
        for (pair in [
            ["![Alt &amp; text][PiCtUrE]", "Alt & text"],
            ["![picture][]", "picture"],
            ["![picture]", "picture"],
        ]) {
            final reference = pair[0];
            final alt = pair[1];
            for (destination in [
                "https://example.com/image.png",
                "./image.png",
                "file:///image.png",
                "data:image/png;base64,iVBORw0KGgo=",
            ]) {
                final source = 'Before $reference after.\n\n[picture]: $destination "Title"\n';
                final cx = new NodeContext();
                cx.offset = 17;
                final document = parse(source, cx);
                final paragraph = findMap(document.blocks, firstParagraph);
                assertEquals(3, paragraph.children_.length, source);
                assertEquals("Before ", paragraph.children_[0].text_);
                assertEquals(" after.", paragraph.children_[2].text_);
                final image = paragraph.children_[1].asImage();
                assertNotNull(image, "reference image");
                assertEquals(destination, image.url);
                assertEquals(alt, image.alt);
                assertEquals("Title", image.title);
                assertTrue(image.span != null && image.span.equals(new Span(24, 24 + reference.length)), '${image.span}');
                assertNull(image.width);
                assertNull(image.height);
                switch image.source() {
                    case ImageSource.Image(_):
                        assertTrue(StringTools.startsWith(destination, "data:"));
                    case ImageSource.Resource(glaze.Resource.Uri(uri)):
                        assertFalse(StringTools.startsWith(destination, "data:"));
                        assertEquals(destination, uri);
                    case _:
                        assertTrue(false, "unexpected image source");
                }
            }
        }
    }

    function testReferenceImageDefinitionLookup() {
        final source = "![alt][Some   LABEL]\n\n> [some label]: first.png\n\n[some label]: second.png \"Ignored\"\n";
        final document = parse(source, new NodeContext());
        final paragraph = findMap(document.blocks, firstParagraph);
        final image = paragraph.children_[0].asImage();
        assertNotNull(image, "reference image");
        assertEquals("first.png", image.url);
        assertNull(image.title);
        assertEquals("alt", image.alt);

        final source = "[picture]: image.png\n\n[![alt][picture]](https://example.com)";
        final document = parse(source, new NodeContext());
        final paragraph = findMap(document.blocks, firstParagraph);
        final image = paragraph.children_[0].asImage();
        assertNotNull(image, "linked reference image");
        assertEquals("image.png", image.url);
        assertEquals("https://example.com", image.link.url);

        final source = "![missing][unknown] ![collapsed][] ![shortcut]";
        final document = parse(source, new NodeContext());
        final paragraph = findMap(document.blocks, firstParagraph);
        assertEquals(source, paragraph.text());
        assertTrue(Lambda.foreach(paragraph.children_, child -> child.asImage() == null));
    }

    function testInlineHtmlImageStaysInMarkdownParagraph() {
        final cx = new NodeContext();
        final document = parse('Before <img src="https://example.com/avatar.png" alt="Avatar" width="32" height="32" /> after.', cx);

        final paragraph = paragraphAt(document, 0);

        assertEquals(3, paragraph.children_.length);
        assertEquals("Before ", paragraph.children_[0].text_);
        assertEquals(" after.", paragraph.children_[2].text_);

        final image = paragraph.children_[1].image;
        assertNotNull(image, "expected inline html image");
        assertEquals("https://example.com/avatar.png", image.url);
        final px32 = DefiniteLength.Absolute(AbsoluteLength.Pixels(32.));
        assertTrue(image.width != null && image.width.equals(px32));
        assertTrue(image.height != null && image.height.equals(px32));
    }

    function testInlineHtmlImageWithoutSizeStaysInMarkdownParagraph() {
        final cx = new NodeContext();
        final document = parse('Before <img src="https://avatars.githubusercontent.com/u/5518"> after.', cx);

        final paragraph = paragraphAt(document, 0);

        assertEquals(3, paragraph.children_.length);
        assertEquals("Before ", paragraph.children_[0].text_);
        assertEquals(" after.", paragraph.children_[2].text_);

        final image = paragraph.children_[1].image;
        assertNotNull(image, "expected inline html image");
        assertEquals("https://avatars.githubusercontent.com/u/5518", image.url);
        assertNull(image.width);
        assertNull(image.height);
    }

    /**
     * A CommonMark soft break reflows to a space, so prose hard-wrapped in
     * the source fills the available width. Every line ending CommonMark
     * recognises has to collapse, not just LF.
     */
    function testSoftBreakReflowsToSpace() {
        for (source in [
            "this sentence\ncontinues as a soft wrap",
            "this sentence\r\ncontinues as a soft wrap",
            "this sentence\rcontinues as a soft wrap",
        ]) {
            final cx = new NodeContext();
            final document = parse(source, cx);

            final paragraph = paragraphAt(document, 0);

            assertEquals(1, paragraph.children_.length, 'source: $source');
            assertEquals("this sentence continues as a soft wrap", paragraph.children_[0].text_, 'source: $source');
        }
    }

    /**
     * The two breaks stay distinguishable in one paragraph: the soft one
     * reflows into the run, the hard one keeps its own newline node.
     */
    function testSoftBreakReflowsWhileHardBreakSurvives() {
        final cx = new NodeContext();
        final document = parse("a\nb  \nc", cx);

        final paragraph = paragraphAt(document, 0);

        final texts = [for (child in paragraph.children_) child.text_];
        assertEquals(haxe.Json.stringify(["a b", "\n", "c"]), haxe.Json.stringify(texts));
    }

    /** A CommonMark hard break renders as a newline. */
    function testHardBreakRendersNewline() {
        for (source in ["Owner: Jane  \nPersona: assistant", "Owner: Jane\\\nPersona: assistant",]) {
            final cx = new NodeContext();
            final document = parse(source, cx);

            final paragraph = paragraphAt(document, 0);

            assertEquals(3, paragraph.children_.length, 'source: $source');
            assertEquals("Owner: Jane", paragraph.children_[0].text_);
            assertEquals("\n", paragraph.children_[1].text_);
            assertEquals("Persona: assistant", paragraph.children_[2].text_);
        }
    }

    function testYamlFrontmatterIsDisabledByDefault() {
        final source = "---\nSome text\n---";
        final cx = new NodeContext();
        final document = parse(source, cx);

        assertTrue(document.blocks[0].match(HorizontalRule(_)));
        switch document.blocks[1] {
            case Heading(level, children, _):
                assertEquals(2, level);
                assertEquals("Some text", children.text());
            case _:
                assertTrue(false, "expected setext heading");
        }
    }

    function testNonMappingYamlFrontmatterFallsBackToCodeBlock() {
        final extensions = new MarkdownExtensions().frontmatter();
        final cx = contextWith(extensions);
        final document = parse("---\n- name: example\n---", cx);

        final codeBlock = codeBlockAt(document, 0);
        assertEquals("yml", codeBlock.lang());
        assertEquals("- name: example", codeBlock.code());
    }

    function testFencedYamlRemainsACodeBlock() {
        final cx = new NodeContext();
        final document = parse("```yaml\nname: example\n```", cx);

        final codeBlock = codeBlockAt(document, 0);
        assertEquals("yaml", codeBlock.lang());
        assertEquals("name: example", codeBlock.code());
    }

    function testCustomBlockParserConvertsTickerSyntaxToCustomNode() {
        final extensions = new MarkdownExtensions().blockParser(parseTickerBlock);

        final cx = contextWith(extensions);
        final document = parse("$TSLA.US", cx);

        final node = switch document.blocks[0] {
            case Custom(node, _): node;
            case _: throw "expected custom markdown node";
        }
        assertEquals("ticker", node.name());
        assertEquals("$TSLA.US", node.asText());
        assertEquals("$TSLA.US", node.asMarkdown());
        final ticker = node.data(Ticker);
        assertNotNull(ticker);
        assertEquals("TSLA.US", ticker.symbol);
        assertEquals("$TSLA.US\n", document.text());
        assertEquals("$TSLA.US", document.toMarkdown());
    }

    function testInlineMathIsEnabledByDefaultAndRespectsCodeAndEscapes() {
        final extensions = new MarkdownExtensions().plugin(new TestInlinePlugin("formula").parseWith((node, _) -> {
            final math = switch node {
                case InlineMath(math): math;
                case _: return null;
            }
            assertEquals("x", math.value);
            return new MarkdownNode("formula", null).text("formula");
        }));
        final cx = contextWith(extensions);
        final document = parse("$x$ `$code$` \\$escaped\\$", cx);
        assertEquals("formula $code$ $escaped$\n", document.text());
        final paragraph = paragraphAt(document, 0);
        assertEquals(1, Lambda.count(paragraph.children_, node -> node.custom != null));
    }

    function testInlineExtensionsPreserveNodesInsideMarksAndGlobalSourceRanges() {
        final source = "中文 **before $x^2$ after** and `$ignored$`";
        final extensions = new MarkdownExtensions().plugin(new TestInlinePlugin("test").parseWith((node, cx) -> {
            final math = switch node {
                case InlineMath(math): math;
                case _: return null;
            }
            assertEquals("$x^2$", cx.nodeSource(node));
            return new MarkdownNode("formula", math.value).text("x²");
        }));
        final cx = contextWith(extensions);
        cx.offset = 50;
        final document = parse(source, cx);
        final paragraph = paragraphAt(document, 0);
        final objects = [for (node in paragraph.children_) if (node.custom != null) node.custom];
        assertEquals(1, objects.length);
        final object = objects[0];
        final start = TextUtils.len(source.substr(0, source.indexOf("$x^2$"))) + 50;
        assertRange(r(start, start + 5), object.sourceRange());
        assertEquals("x²", object.asText());
        assertEquals("$x^2$", object.asMarkdown());
        assertEquals("x²", object.accessibilityName());
        assertEquals("中文 before x² after and $ignored$\n", document.text());
        assertTrue(document.toMarkdown().indexOf("**before $x^2$ after**") != -1, document.toMarkdown());
    }

    function testBlockMathParsesAsABlockAndFallsBackToACodeBlock() {
        // `$$` is a block fence. With only the inline construct enabled it was
        // swallowed as one long inline formula, so a block plugin matching
        // `Node.Math` never fired.
        final source = "$$\n\\sum_{i=1}^{n} i\n$$";
        final cx = new NodeContext();
        final document = parse(source, cx);
        final code = codeBlockAt(document, 0);
        assertEquals("\\sum_{i=1}^{n} i", code.code());
        assertTrue(document.toMarkdown().indexOf("\\sum_{i=1}^{n} i") != -1);
    }

    function testUnclaimedInlineMathParsesItsSpanAsProse() {
        // Two dollar amounts pair up into an unclaimed math span. What lies
        // between them is ordinary prose: inline HTML there must still pair
        // with the tags outside the span, and emphasis inside it must render.
        final source = "EPS of <strong>$1.56</strong> beat the <strong>$1.50</strong> consensus, *up $2*";
        final cx = new NodeContext();
        final document = parse(source, cx);
        assertEquals("EPS of $1.56 beat the $1.50 consensus, up $2\n", document.text());
        final paragraph = paragraphAt(document, 0);
        assertEquals(haxe.Json.stringify(["$1.56", "$1.50"]), haxe.Json.stringify(boldRuns(paragraph)));
        assertTrue(Lambda.exists(paragraph.children_, node -> Lambda.exists(node.marks_, ranged -> ranged.mark.italic
            && TextUtils.slice(node.text_, ranged.range.start, ranged.range.end) == "up $2")));
        assertTrue(document.toMarkdown().indexOf("$1.56") != -1);
    }

    function testClaimedInlineMathSurvivesProseFlattening() {
        final extensions = new MarkdownExtensions().plugin(new TestInlinePlugin("formula").parseWith((node, _) -> {
            final math = switch node {
                case InlineMath(math): math;
                case _: return null;
            }
            return new MarkdownNode("formula", null).text('[${math.value}]');
        }));
        final cx = contextWith(extensions);
        final document = parse("area $x^2$ costs $5 and $10", cx);
        assertEquals("area [x^2] costs [5 and ]10\n", document.text());
    }

    function testInlineHtmlFormattingTagsPairAcrossSiblings() {
        final source = "a <strong>b *c* <em>d</em></strong> e <b>f</b> <i>g</i> <del>h</del> <br> <strong>unclosed";
        final cx = new NodeContext();
        final document = parse(source, cx);
        assertEquals("a b c d e f g h \n unclosed\n", document.text());
        final paragraph = paragraphAt(document, 0);
        assertEquals(haxe.Json.stringify(["b c d", "f"]), haxe.Json.stringify(boldRuns(paragraph)));
        assertEquals(haxe.Json.stringify(["c", "d", "g"]), haxe.Json.stringify(markedRuns(paragraph, mark -> mark.italic)));
        assertEquals(haxe.Json.stringify(["h"]), haxe.Json.stringify(markedRuns(paragraph, mark -> mark.strikethrough)));
    }

    /**
     * Inline `<mark>` is paired like `<strong>` and keeps the same color
     * rules as the block HTML path: default yellow, `color`, then
     * `style="background-color"`.
     */
    function testInlineHtmlMarkAppliesHighlightColors() {
        final source = 'Plain <mark>highlighted</mark> text and ' + '<mark data_id="1" color="#ff000059">red</mark> and '
            + '<mark style="background-color: #336699">hex</mark>.';
        final cx = new NodeContext();
        final document = parse(source, cx);
        assertEquals("Plain highlighted text and red and hex.\n", document.text());
        final paragraph = paragraphAt(document, 0);
        final runs = highlightRuns(paragraph);
        final expected:Array<{text:String, color:Hsla}> = [
            {text: "highlighted", color: rgb(0xfef08a).toHsla()},
            {text: "red", color: Rgba.parse("#ff000059").toHsla()},
            {text: "hex", color: Rgba.parse("#336699").toHsla()},
        ];
        assertEquals(expected.length, runs.length);
        for (i in 0...expected.length) {
            if (i >= runs.length)
                break;
            assertEquals(expected[i].text, runs[i].text);
            assertTrue(expected[i].color.equals(runs[i].color), '${expected[i].color} != ${runs[i].color}');
        }
    }

    function testUnclaimedInlineMathKeepsItsLiteralSource() {
        // Math parsing is on by default, so prose that merely contains dollar
        // signs parses as a math node. With no plugin to render it, the text
        // must survive display and a Markdown round trip untouched.
        final source = "spent $5 and $10 today";
        final cx = new NodeContext();
        final document = parse(source, cx);
        assertEquals("spent $5 and $10 today\n", document.text());
        assertTrue(document.toMarkdown().indexOf("spent $5 and $10 today") != -1);
        final paragraph = paragraphAt(document, 0);
        assertTrue(Lambda.foreach(paragraph.children_, node -> node.custom == null));
    }

    function testInlineObjectMarkdownRoundtripPreservesNestedEmphasis() {
        for (source in ["*before $x$ after*", "*before **$x$** after*", "**before *$x$* after**",]) {
            final cx = contextWith(new MarkdownExtensions().plugin(new TestInlinePlugin("test").parseWith((node, _) -> switch node {
                case InlineMath(math): new MarkdownNode("math", null).text(math.value);
                case _: null;
            })));
            final original = parse(source, cx);
            final markdown = original.toMarkdown();
            final reparsed = parse(markdown, cx);
            final before = paragraphAt(original, 0);
            final after = paragraphAt(reparsed, 0);
            final beforeObject = Lambda.find(before.children_, node -> node.custom != null);
            final afterObject = Lambda.find(after.children_, node -> node.custom != null);
            assertNotNull(beforeObject);
            assertNotNull(afterObject);
            assertEquals(before.text(), after.text(), '$source -> $markdown');
            assertEquals(describeMarks(beforeObject.marks_), describeMarks(afterObject.marks_), '$source -> $markdown');
        }
    }

    static function describeMarks(marks:Array<RangedMark>):String {
        return [
            for (m in marks)
                '${m.range} b=${m.mark.bold} i=${m.mark.italic} s=${m.mark.strikethrough} u=${m.mark.underline} c=${m.mark.code} h=${m.mark.highlight} l=${m.mark.link != null ? m.mark.link.url : null}'
        ].join('; ');
    }

    function testInlineParserWithoutMetadataFallsBackToOriginalSource() {
        final cx = contextWith(new MarkdownExtensions().plugin(new TestInlinePlugin("test").parseWith((node, _) -> node.match(InlineCode(_)) ? new MarkdownNode("opaque",
            null) : null)));
        final document = parse("`原子`", cx);
        final paragraph = paragraphAt(document, 0);
        final node = paragraph.children_[0].custom;
        assertNotNull(node);
        assertEquals("`原子`", node.asText());
        assertEquals("`原子`", node.asMarkdown());
        assertEquals("`原子`", node.accessibilityName());
    }

    function testCustomBlockPluginRegistersParserAndRenderer() {
        final extensions = new MarkdownExtensions().plugin(new TickerPlugin("ticker"));

        final cx = contextWith(extensions);
        final document = parse("$TSLA.US", cx);

        final node = switch document.blocks[0] {
            case Custom(node, _): node;
            case _: throw "expected custom markdown node";
        }
        assertEquals("ticker", node.name());
        final ticker = node.data(Ticker);
        assertNotNull(ticker);
        assertEquals("TSLA.US", ticker.symbol);
    }

    // Extra check of the port: the Rust `Result` value.

    function testTryParseReturnsTheDocument() {
        final result = MarkdownFormat.tryParse("plain", new NodeContext());
        assertNotNull(result.document);
        assertNull(result.error);
    }

}

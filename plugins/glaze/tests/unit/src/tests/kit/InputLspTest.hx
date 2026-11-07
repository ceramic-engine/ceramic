// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/mod.rs, lsp/completions.rs,
// lsp/document_colors.rs, lsp/semantic_tokens.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.HighlightStyle;
import gpui.Hsla;
import gpui.Range;
import gpui.base.input.ColorInformation;
import gpui.base.input.CompletionHighlighter;
import gpui.base.input.CompletionItem;
import gpui.base.input.Completions;
import gpui.base.input.HighlightStyleResolver;
import gpui.base.input.Lsp;
import gpui.base.input.Lsp.DocumentColor;
import gpui.base.input.Lsp.SemanticTokenSpan;
import gpui.base.input.LspColor;
import gpui.base.input.LspPosition;
import gpui.base.input.LspRange;
import gpui.base.input.SemanticToken;
import gpui.base.input.SemanticTokens;
import gpui.base.input.SemanticTokensLegend;
import ropey.Rope;
import testing.TestCase;

private class TestTheme implements HighlightStyleResolver {

    public function new() {}

    public function style(name:String):Null<HighlightStyle> {
        return (name == "keyword" || name == "comment") ? new HighlightStyle(new Hsla(0.5, 0.5, 0.5, 1.)) : null;
    }

}

/**
 * Tests of the LSP data of the editor (Rust `lsp/*.rs`).
 */
class InputLspTest extends TestCase {

    static inline function r(a:Int, b:Int):Range {
        return new Range(a, b);
    }

    static function list(ranges:Array<Range>):String {
        return [for (range in ranges) range.toString()].join(',');
    }

    static function item(label:String, ?filterText:String):CompletionItem {
        return new CompletionItem(label, null, null, null, null, filterText);
    }

/// lsp/mod.rs

    function testLspBuilder() {
        final highlighter:CompletionHighlighter = Completions.highlightContains;
        final lsp = Lsp.defaultValue().withCompletionHighlighter(highlighter);
        assertTrue(Reflect.compareMethods(lsp.completionHighlighter(), highlighter));

        final replacement:CompletionHighlighter = Completions.highlightCharacters;
        lsp.setCompletionHighlighter(replacement);
        assertTrue(Reflect.compareMethods(lsp.completionHighlighter(), replacement));
    }

/// lsp/completions.rs

    function testPrefixUsesTheQueryLengthUnlessFilterTextIsSet() {
        assertEquals(list([r(0, 2)]), list(Completions.highlightPrefix("fl", item("flag"))));
        assertEquals(list([r(0, 1)]), list(Completions.highlightPrefix("fl", item("flag", "f"))));
        assertEquals(list([r(0, 4)]), list(Completions.highlightPrefix("flagpole", item("flag"))));
        assertEquals(0, Completions.highlightPrefix("", item("flag")).length);
    }

    function testPrefixDoesNotSplitACharacter() {
        assertEquals(list([r(0, 3)]), list(Completions.highlightPrefix("你", item("你好"))));
        assertEquals(0, Completions.highlightPrefix("a", item("你")).length);
    }

    function testContainsHighlightsTheFirstContiguousMatch() {
        // "dialog" itself ends in "log", so that hit comes before the suffix.
        assertEquals(list([r(3, 6)]), list(Completions.highlightContains("log", item("dialog_log"))));
        assertEquals(list([r(3, 6)]), list(Completions.highlightContains("LOG", item("dialog_log"))));
        assertEquals(list([r(4, 7)]), list(Completions.highlightContains("log", item("catalog"))));
        assertEquals(list([r(3, 9)]), list(Completions.highlightContains("好世", item("你好世界"))));
        assertEquals(0, Completions.highlightContains("log", item("flag")).length);
        assertEquals(0, Completions.highlightContains("", item("flag")).length);
    }

    function testCharactersHighlightGapsAndMergeAdjacentHits() {
        assertEquals(list([r(0, 2)]), list(Completions.highlightCharacters("fl", item("flag"))));
        assertEquals(list([r(0, 1), r(2, 3)]), list(Completions.highlightCharacters("fl", item("file_loader"))));
        assertEquals(list([r(0, 3), r(6, 9)]), list(Completions.highlightCharacters("你世", item("你好世界"))));
        assertEquals(0, Completions.highlightCharacters("fx", item("flag")).length);
        assertEquals(0, Completions.highlightCharacters("", item("flag")).length);
    }

/// lsp/document_colors.rs

    function testDocumentColorsFromResponseEnforcesLimit() {
        final color = new ColorInformation(new LspRange(new LspPosition(0, 0), new LspPosition(0, 1)), new LspColor(1., 0., 0., 1.));
        final colors = [for (_ in 0...10001) color];

        assertEquals(10000, Lsp.documentColorsFromResponse(colors.slice(0, 10000)).length);
        assertNull(Lsp.documentColorsFromResponse(colors));
    }

    function testDocumentColorsForRangeIgnoresEmptyAndInvertedRanges() {
        final text = Rope.fromStr("01234567890123456789");
        final lsp = Lsp.defaultValue();
        lsp.documentColors.push(new DocumentColor(new LspRange(new LspPosition(0, 10), new LspPosition(0, 5)), Hsla.red()));
        lsp.documentColors.push(new DocumentColor(new LspRange(new LspPosition(0, 10), new LspPosition(0, 10)), Hsla.green()));
        lsp.documentColors.push(new DocumentColor(new LspRange(new LspPosition(0, 5), new LspPosition(0, 10)), Hsla.blue()));

        final colors = lsp.documentColorsForRange(text, r(0, 0));
        assertEquals(1, colors.length);
        assertTrue(r(5, 10).equals(colors[0].range));
        assertTrue(Hsla.blue().equals(colors[0].color));
    }

/// lsp/semantic_tokens.rs

    static function legend():SemanticTokensLegend {
        return new SemanticTokensLegend(["keyword", "comment"], []);
    }

    function testDecodeSemanticTokensDelta() {
        final tokens = new SemanticTokens([new SemanticToken(0, 0, 4, 0, 0), new SemanticToken(1, 2, 5, 1, 0)]);

        final decoded = Lsp.decodeSemanticTokens(tokens, legend());
        assertEquals(2, decoded.length);
        assertTrue(new LspPosition(0, 0).equals(decoded[0].range.start));
        assertTrue(new LspPosition(0, 4).equals(decoded[0].range.end));
        assertEquals("keyword", decoded[0].name);
        assertTrue(new LspPosition(1, 2).equals(decoded[1].range.start));
        assertTrue(new LspPosition(1, 7).equals(decoded[1].range.end));
        assertEquals("comment", decoded[1].name);
    }

    function testDecodeSkipsOutOfLegendIndex() {
        final tokens = new SemanticTokens([new SemanticToken(0, 0, 3, 99, 0)]); // out of legend bounds
        assertEquals(0, Lsp.decodeSemanticTokens(tokens, legend()).length);
    }

    function testForRangeResolvesAndWindows() {
        final text = Rope.fromStr("SELECT * FROM users\n-- a comment line\n");
        final theme = new TestTheme();

        final lsp = Lsp.defaultValue();
        lsp.semanticTokens = [
            new SemanticTokenSpan(new LspRange(new LspPosition(0, 0), new LspPosition(0, 6)), "keyword"),
            new SemanticTokenSpan(new LspRange(new LspPosition(1, 0), new LspPosition(1, 17)), "comment"),
        ];

        final styles = lsp.semanticTokensForRange(text, r(0, 19), theme);
        assertEquals(1, styles.length, "only the line-0 token should be windowed in");
        assertTrue(r(0, 6).equals(styles[0].range), "keyword token maps to bytes 0..6");
        assertFalse(styles[0].style.equals(new HighlightStyle()), "'keyword' should resolve to a non-default style on default-dark");
    }

    function testForRangeBinarySearchWindow() {
        final text = Rope.fromStr([for (_ in 0...100) "foo bar\n"].join(''));
        final theme = new TestTheme();

        final lsp = Lsp.defaultValue();
        lsp.semanticTokens = [for (line in 0...100) new SemanticTokenSpan(new LspRange(new LspPosition(line, 0), new LspPosition(line, 3)), "keyword")];

        final lineBytes = "foo bar\n".length;
        final start = 50 * lineBytes;
        final styles = lsp.semanticTokensForRange(text, r(start, start + 3), theme);
        assertEquals(1, styles.length);
        assertTrue(r(start, start + 3).equals(styles[0].range));

        assertEquals(0, lsp.semanticTokensForRange(text, r(0, 0), theme).length);
    }

}

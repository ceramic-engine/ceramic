// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/syntect_backend.rs (tests),
// crates/component/src/highlighter/wasm_stub.rs (registry_compat_tests),
// crates/component/src/text/mod.rs (code block highlighter tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic, on TextMate grammars. See NOTICE.md.
package tests.kit;

#if !macro
import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.Range;
import glaze.Rgba;
import glaze.kit.base.input.DiagnosticSeverity;
import glaze.kit.base.input.FoldRange;
import glaze.kit.base.input.HighlightStyleResolver;
import glaze.kit.base.input.InputEdit;
import glaze.kit.base.input.StyledRange;
import glaze.kit.base.text.CodeBlock;
import glaze.kit.highlighter.DiagnosticStyles;
import glaze.kit.highlighter.GrammarCatalog;
import glaze.kit.highlighter.HighlightTheme;
import glaze.kit.highlighter.HighlightTheme.HighlightThemeStyle;
import glaze.kit.highlighter.Highlighter;
import glaze.kit.highlighter.LanguageName;
import glaze.kit.highlighter.LanguageRegistry;
import glaze.kit.highlighter.LanguageRegistry.LanguageConfig;
import glaze.kit.highlighter.SyntaxColors;
import glaze.kit.highlighter.SyntaxHighlighter;
import glaze.kit.highlighter.TextMateBackend;
import glaze.kit.highlighter.TextMateBackend.Highlight;
import glaze.kit.highlighter.TextMateBackend.TextMateInputHighlighter;
import glaze.kit.highlighter.TextMateGrammars;
import glaze.kit.text.TextView;
import glaze.kit.theme.Theme;
import ropey.Rope;

using glaze.kit.base.input.RopeExt;

private class Named implements HighlightStyleResolver {
    public function new() {}

    public function style(_:String):Null<HighlightStyle> {
        return new HighlightStyle();
    }
}
#end

/**
 * Tests of the code highlighter (`glaze.kit.highlighter`).
 *
 * Ported from gpui-kit: the tests of the syntect backend (on the TextMate
 * grammars), of the registry stub and of the component code block
 * highlighter (the syntect variants, and the tree-sitter ones that do not
 * depend on tree-sitter, adapted to a TextMate grammar).
 *
 * Added for the port: the scope to highlight name rules, the theme types
 * (serde names, stub status colors), the token colors of 40 samples compared
 * with the real vscode-textmate (`tests/unit/data/highlight/truth.json`, see
 * `record.mjs` there), and the incremental editor highlighter compared with
 * a whole-document tokenization after edits.
 */
@:access(glaze.kit.highlighter)
@:access(glaze.kit.text.TextView)
class HighlighterTest #if !macro extends KitTestCase #end {

    #if !macro

    static var grammarsAdded = false;

    override function setup() {
        super.setup();
        addGrammars();
        // Token comparisons must not depend on the speed of the machine
        TextMateBackend.lineTimeLimit = 0;
    }

    override function teardown() {
        TextMateBackend.lineTimeLimit = TextMateBackend.LINE_TIME_LIMIT;
        Highlighter.disable();
        super.teardown();
    }

    /**
     * On node and on Unity (C#, assets in Unity's Resources, no file) there is
     * no synchronous read of the assets: the grammar files are embedded in the
     * test build and handed to the asset source.
     */
    static function addGrammars():Void {
        if (grammarsAdded)
            return;
        grammarsAdded = true;
        #if (js || cs)
        final files:haxe.DynamicAccess<String> = haxe.Json.parse(grammarFiles());
        for (name => content in files) {
            glaze.App.defaultAssetSource().add(GrammarCatalog.FOLDER + '/' + name, haxe.io.Bytes.ofString(content));
        }
        #end
    }

    static function names(language:String, code:String):Array<String> {
        final syntax = TextMateBackend.findSyntax(language);
        final bytes = haxe.io.Bytes.ofString(code);
        return [
            for (highlight in TextMateBackend.parse(syntax, code))
                highlight.name + ':' + bytes.getString(highlight.start, highlight.end - highlight.start)
        ];
    }

    static function hex(color:Null<Hsla>):Null<String> {
        if (color == null)
            return null;
        final rgba = Rgba.fromHsla(color);
        inline function byte(v:Float):String
            return StringTools.hex(Std.int(Math.round(v * 255)), 2).toLowerCase();
        return '#' + byte(rgba.r) + byte(rgba.g) + byte(rgba.b) + byte(rgba.a);
    }

    // language_name.rs

    function testLanguageNameAliases() {
        assertEquals("text", LanguageName.languageName("Plain"));
        assertEquals("json", LanguageName.languageName("jsonc"));
        assertEquals("bash", LanguageName.languageName("sh"));
        assertEquals("cpp", LanguageName.languageName("C++"));
        assertEquals("markdown_inline", LanguageName.languageName("markdown-inline"));
        assertEquals("python", LanguageName.languageName("pyi"));
        assertEquals("haxe", LanguageName.languageName("Haxe"));
    }

    // wasm_stub.rs: registry_compat_tests

    function testRegistrationsPreserveExactNamesWithoutAliasFallback() {
        final registry = new LanguageRegistry();
        registry.register("json", new LanguageConfig("canonical"));
        assertNull(registry.language("jsonc"));
        registry.register("jsonc", new LanguageConfig("custom alias"));
        registry.register("JSON", new LanguageConfig("custom uppercase"));
        assertEquals("canonical", registry.language("json").name);
        assertEquals("custom alias", registry.language("jsonc").name);
        assertEquals("custom uppercase", registry.language("JSON").name);
        assertNull(registry.language("Json"));
        final names = registry.languages();
        names.sort(Reflect.compare);
        assertEquals("JSON,json,jsonc", names.join(','));
        assertEquals("jsonc", registry.editingLanguageName("jsonc"));
        assertEquals("JSON", registry.editingLanguageName("JSON"));
        assertEquals("python", registry.editingLanguageName("pyi"));
    }

    // Theme types

    function testSyntaxStylesFallBackToTheirPrefix() {
        final light = HighlightTheme.defaultLight();
        assertEquals('#0433ffff', hex(light.highlightStyle("keyword").color));
        // `keyword.modifier` falls back to `keyword`.
        assertEquals('#0433ffff', hex(light.highlightStyle("keyword.modifier").color));
        assertNull(light.highlightStyle(""));
        assertNull(light.highlightStyle("nothing.here"));
        // The default theme's `comment.doc` entry is not read (serde reads
        // `comment_doc`), so it falls back to `comment`.
        assertNull(light.style.syntax.get("comment.doc"));
        assertEquals('#007fffff', hex(light.highlightStyle("comment.doc").color));
        // Font styles and weights.
        assertEquals(glaze.FontStyle.Italic, light.highlightStyle("emphasis").fontStyle);
        assertEquals(700., (light.highlightStyle("emphasis.strong").fontWeight : Float));
        assertEquals(600., (HighlightTheme.defaultDark().highlightStyle("title").fontWeight : Float));
        // `styleForIndex` follows `HIGHLIGHT_NAMES`.
        assertEquals(41, SyntaxColors.HIGHLIGHT_NAMES.length);
        assertEquals('#0433ffff', hex(light.styleForIndex(SyntaxColors.HIGHLIGHT_NAMES.indexOf("keyword")).color));
        assertNull(light.styleForIndex(99));
        // The resolver is the theme.
        assertTrue(light.resolver() == light.resolver());
        assertEquals('#036a07ff', hex(light.resolver().style("string.other").color));
    }

    function testHighlightThemeStyleReadsTheSerdeNamesOfTheStub() {
        final style = HighlightThemeStyle.fromJson(haxe.Json.parse('{
            "editor.background": "#ffffff",
            "editor_background": "#102030",
            "editor_active_line": "#abc",
            "editor.gutter.background": "#00000080",
            "error": "#ff0000",
            "syntax": {"comment_doc": {"color": "#112233", "font_style": "underline", "font_weight": 650}, "type": {"font_weight": 300}}
        }'));
        assertEquals('#102030ff', hex(style.editorBackground));
        assertEquals('#aabbccff', hex(style.editorActiveLine));
        assertEquals('#00000080', hex(style.editorGutterBackground));
        assertNull(style.editorInvisible);
        final doc = style.syntax.style("comment.doc");
        assertEquals('#112233ff', hex(doc.color));
        // Underline has no font style; 650 is not a weight serde accepts.
        assertEquals(glaze.FontStyle.Normal, doc.fontStyle);
        assertNull(doc.fontWeight);
        assertEquals(300., (style.syntax.style("type").fontWeight : Float));
        // The default themes keep their editor colors under dotted keys:
        // gpui-kit without tree-sitter ignores them.
        assertNull(HighlightTheme.defaultLight().style.editorBackground);
        assertNull(HighlightTheme.defaultDark().style.editorActiveLine);
    }

    function testStatusColorsOfTheStubAreTransparent() {
        app.update(cx -> {
            glaze.kit.Component.init(cx);
            for (severity in [DiagnosticSeverity.Error, DiagnosticSeverity.Warning, DiagnosticSeverity.Info, DiagnosticSeverity.Hint]) {
                assertTrue(DiagnosticStyles.diagnosticForeground(severity, cx).equals(new Hsla()));
                assertTrue(DiagnosticStyles.diagnosticBackground(severity, cx).equals(new Hsla()));
                assertTrue(DiagnosticStyles.diagnosticBorder(severity, cx).equals(new Hsla()));
            }
        });
    }

    function testThemeConfigsBuildTheirHighlightTheme() {
        final theme = new Theme();
        assertTrue(theme.highlightTheme == HighlightTheme.defaultLight());
        final dark = glaze.kit.theme.DefaultThemeColors.themes().filter(t -> t.mode.isDark())[0];
        theme.applyConfig(dark);
        assertEquals("Default Dark", theme.highlightTheme.name);
        assertTrue(theme.highlightTheme.equals(HighlightTheme.defaultDark()));
        assertFalse(theme.highlightTheme == HighlightTheme.defaultDark());
        assertTrue(theme.clone().highlightTheme == theme.highlightTheme);
    }

    // syntect_backend.rs

    function testCommonFenceNamesFindASyntax() {
        for (language in [
            "rust", "rs", "toml", "typescript", "ts", "tsx", "javascript", "js", "python", "py", "bash", "sh", "yaml", "yml", "json", "jsonc",
            "markdown", "md", "go", "c", "cpp", "csharp", "java", "kotlin", "swift", "ruby", "html", "css", "sql", "diff", "make",
            "dockerfile", "zig", "lua", "php"
        ]) {
            assertTrue(TextMateBackend.findSyntax(language) != null, '`$language` has no syntax');
        }
        assertNull(TextMateBackend.findSyntax("text"), "plain text is not highlighted");
        assertNull(TextMateBackend.findSyntax("no-such-language"));
        // The names gpui-kit's tree-sitter languages use, too.
        for (language in [
            "astro", "c++", "cmake", "cs", "ejs", "elixir", "ex", "erb", "graphql", "kt", "makefile", "markdown_inline", "markdown-inline",
            "proto", "protobuf", "rb", "scala", "scss", "svelte", "haxe", "hx"
        ]) {
            assertTrue(TextMateBackend.findSyntax(language) != null, '`$language` has no syntax');
        }
    }

    function testScopesMapOntoTheThemesHighlightNames() {
        final toml = names("toml", "[package]\nname = \"demo\" # the name\nversion = 1\n");
        assertTrue(toml.contains('string:"demo"'), toml.join(' | '));
        assertTrue(toml.filter(n -> StringTools.startsWith(n, 'comment:') && n.indexOf('the name') >= 0).length > 0, toml.join(' | '));
        assertTrue(toml.contains('number:1\n'), toml.join(' | '));

        final rust = names("rust", "fn main() { let x = 42; }\n");
        assertTrue(rust.contains('keyword:fn'), rust.join(' | '));
        assertTrue(rust.contains('function:main'), rust.join(' | '));
        assertTrue(rust.contains('number:42'), rust.join(' | '));
    }

    function testStyleRunsCoverTheRangeWithoutGaps() {
        final runs = TextMateBackend.resolveStyles([
            new Highlight(2, 4, "keyword"),
            new Highlight(6, 8, "string")
        ], new Range(0, 10), new Named());
        assertEquals("0..2,2..4,4..6,6..8,8..10", [for (run in runs) run.range.start + '..' + run.range.end].join(','));
    }

    function testAnEditShiftsLaterHighlightsAndDropsTouchedOnes() {
        final highlights = [
            new Highlight(0, 2, "keyword"),
            new Highlight(4, 6, "string"),
            new Highlight(8, 10, "number")
        ];
        final origin = new glaze.kit.base.input.RopePoint(0, 0);
        TextMateBackend.shift(highlights, new InputEdit(5, 5, 8, origin, origin, origin));
        assertEquals("(0..2, keyword),(11..13, number)", highlights.join(','));
    }

    function testBracesOutsideStringsAndCommentsFold() {
        final folds = TextMateBackend.braceFoldRanges("fn a() {\n  let s = \"{\";\n  // }\n}\n");
        assertEquals(1, folds.length);
        assertTrue(folds[0].equals(new FoldRange(0, 3)));
    }

    // The scope rules of `semantic_name`, including what follows from their
    // order in the original.

    function testScopesMapByTheSyntectBackendRules() {
        final cases = [
            "comment.line.double-slash.rust" => "comment",
            "comment.block.documentation.rust" => "comment.doc",
            "punctuation.definition.comment.rust" => null,
            "punctuation.definition.string.begin.rust" => null,
            "string.quoted.double.rust" => "string",
            "string.regexp.js" => "string.regex",
            "constant.character.escape.rust" => "string.escape",
            "constant.numeric.decimal.rust" => "number",
            "constant.language.boolean.true.ts" => "boolean",
            "constant.language.null.js" => "constant",
            "support.constant.math.js" => "constant",
            "keyword.operator.arithmetic.rust" => "operator",
            "keyword.control.import.js" => "preproc",
            "keyword.control.rust" => "keyword",
            "storage.modifier.rust" => "keyword",
            "storage.type.function.rust" => "keyword",
            "entity.name.function.rust" => "function",
            "support.function.builtin.python" => "function",
            "entity.name.type.struct.rust" => "type",
            "support.class.builtin.js" => "type",
            "entity.name.tag.html" => "tag",
            "entity.other.attribute-name.html" => "attribute",
            "entity.name.label.c" => "label",
            "markup.heading.markdown" => "title",
            "entity.name.section.markdown" => "title",
            "variable.language.this.js" => "variable.special",
            "variable.other.property.js" => "property",
            "support.variable.property.js" => "property",
            "variable.other.readwrite.js" => "variable",
            "markup.bold.markdown" => "emphasis.strong",
            "markup.italic.markdown" => "emphasis",
            "markup.underline.link.markdown" => "link_uri",
            "markup.raw.block.markdown" => "text.literal",
            "markup.list.unnumbered.markdown" => "punctuation.list_marker",
            "punctuation.section.block.begin.rust" => "punctuation.bracket",
            "punctuation.definition.block.js" => "punctuation.bracket",
            "punctuation.separator.comma.rust" => "punctuation.delimiter",
            "punctuation.terminator.statement.js" => "punctuation.delimiter",
            "punctuation.accessor.js" => "punctuation",
            "invalid.illegal.js" => null,
            "source.rust" => null,
            "text.html.basic" => null,
            "entity.other.unknown" => null,
            // `is` matches whole segments only.
            "keywords.x" => null,
            "commentary" => null,
            // gpui-kit checks `meta` before `meta.preprocessor`,
            // `meta.function-call` and `meta.mapping.key`: those branches
            // are never reached and the scopes name nothing.
            "meta.preprocessor.c" => null,
            "meta.function-call.python" => null,
            "meta.mapping.key.yaml" => null,
            // Every `storage.type...` scope contains "type", so the
            // `type` branch is never reached: `int` is a keyword too.
            "storage.type.primitive.java" => "keyword",
            "storage.type.built-in.primitive.c" => "keyword"
        ];
        for (scope => expected in cases) {
            assertEquals(expected, TextMateBackend.semanticName(scope), scope);
        }
    }

    // text/mod.rs

    function testHighlightsACodeFence() {
        final code = "[package]\nname = \"demo\"\n";
        final highlighter = TextView.componentCodeBlockHighlighter(HighlightTheme.defaultLight());
        final styles = highlighter(CodeBlock.fromCode(code, "toml"));
        final string = code.indexOf("\"demo\"");
        assertTrue(styles.filter(s -> s.range.start <= string && string < s.range.end && s.style.color != null).length > 0,
            "the string must be colored");
        assertEquals(code.length, styles[styles.length - 1].range.end, "the runs cover the whole block");
        assertEquals(0, highlighter(CodeBlock.fromCode(code, "no-such-language")).length);
        assertEquals(0, highlighter(CodeBlock.fromCode(code)).length);
    }

    function testStylesFollowTheHighlightThemeTheyWereBuiltWith() {
        final code = '{"value": 42}';
        final number = code.indexOf("42");
        final light = HighlightTheme.defaultLight();
        final dark = HighlightTheme.defaultDark();
        final lightNumber = light.highlightStyle("number").color;
        final darkNumber = dark.highlightStyle("number").color;
        assertFalse(lightNumber.equals(darkNumber), "the default themes must use different number colors");

        function colorAt(styles:Array<StyledRange>):Null<Hsla> {
            for (s in styles)
                if (s.range.start <= number && s.range.end >= number + 2)
                    return s.style.color;
            return null;
        }
        final block = CodeBlock.fromCode(code, "json");
        assertTrue(colorAt(TextView.componentCodeBlockHighlighter(light)(block)).equals(lightNumber));
        assertTrue(colorAt(TextView.componentCodeBlockHighlighter(dark)(block)).equals(darkNumber),
            "a theme change must not reuse syntax styles from the previous theme");
    }

    function testSharedHighlighterIsReusedForTheSameTheme() {
        final generation = 1000000;
        final light = HighlightTheme.defaultLight();
        final dark = HighlightTheme.defaultDark();
        final first = TextView.sharedCodeBlockHighlighterAt(light, generation);
        final again = TextView.sharedCodeBlockHighlighterAt(light, generation);
        final other = TextView.sharedCodeBlockHighlighterAt(dark, generation);
        assertTrue(Reflect.compareMethods(first, again));
        assertFalse(Reflect.compareMethods(first, other));
    }

    function testRegisteringALanguageReplacesTheSharedHighlighter() {
        final light = HighlightTheme.defaultLight();
        final before = TextView.sharedCodeBlockHighlighterAt(light, 1000001);
        final after = TextView.sharedCodeBlockHighlighterAt(light, 1000002);
        assertFalse(Reflect.compareMethods(before, after));
    }

    function testRegisteringAGrammarMakesItsLanguageHighlight() {
        final generation = TextMateGrammars.generation;
        assertNull(TextMateBackend.findSyntax("tiny-lang"));
        TextMateGrammars.register("tiny-lang", '{"scopeName": "source.tiny", "patterns": [{"match": "\\\\d+", "name": "constant.numeric.tiny"}]}', ["tiny"]);
        assertTrue(TextMateGrammars.generation != generation);
        assertEquals("number:42", names("tiny", "a 42 b").join(','));
    }

    function testComponentInitializationInstallsCodeHighlightingWhenEnabled() {
        app.update(cx -> {
            glaze.kit.Component.init(cx);
            assertFalse(glaze.kit.base.text.TextView.TextViewDefaults.global(cx).hasCodeBlockHighlighter());
            Highlighter.enable(cx);
            assertTrue(glaze.kit.base.text.TextView.TextViewDefaults.global(cx).hasCodeBlockHighlighter());
            Highlighter.disable(cx);
            assertFalse(glaze.kit.base.text.TextView.TextViewDefaults.global(cx).hasCodeBlockHighlighter());
        });
    }

    function testInputFactoryAndCaptureNamesFollowTheSwitch() {
        final factory = Highlighter.inputHighlighterFactory();
        assertNull(factory("rust"));
        assertEquals(0, new SyntaxHighlighter("rust").captureNames(Rope.fromStr("fn a() {}")).length);
        Highlighter.enable();
        assertEquals("rust", factory("rust").language());
        assertNull(factory("text"));
        final captures = new SyntaxHighlighter("rust").captureNames(Rope.fromStr("fn a() {}"));
        assertEquals("keyword", captures[0].name);
        assertEquals(0, captures[0].range.start);
        assertEquals(2, captures[0].range.end);
        // The stub's `language()` is always empty.
        assertEquals("", new SyntaxHighlighter("rust").language());
    }

    // Offsets

    function testOffsetsAreUtf8Bytes() {
        final code = "x = \"é😀\" # ü\n";
        final all = names("python", code);
        assertTrue(all.contains('string:é😀') || all.filter(n -> n.indexOf('é😀') >= 0).length > 0, all.join(' | '));
        final runs = TextMateBackend.highlightCode("python", code, HighlightTheme.defaultLight().resolver());
        assertEquals(haxe.io.Bytes.ofString(code).length, runs[runs.length - 1].range.end);
        final bytes = haxe.io.Bytes.ofString(code);
        final comment = runs.filter(r -> bytes.getString(r.range.start, r.range.end - r.range.start).indexOf('# ü') == 0);
        assertEquals(1, comment.length);
        assertEquals('#007fffff', hex(comment[0].style.color));
    }

    // Colors of real grammars, against vscode-textmate

    function testTokenColorsMatchVscodeTextmate() {
        final truth:Dynamic = haxe.Json.parse(truthJson());
        final samples:haxe.DynamicAccess<String> = haxe.Json.parse(samplesJson());
        final cases:Array<Dynamic> = truth.cases;
        var lines = 0;
        for (c in cases) {
            final text = samples.get(c.sample);
            final light = TextMateBackend.highlightCode(c.token, text, HighlightTheme.defaultLight().resolver());
            final dark = TextMateBackend.highlightCode(c.token, text, HighlightTheme.defaultDark().resolver());
            lines += compareWithTruth(c.sample + ' (light)', text, light, c.light);
            compareWithTruth(c.sample + ' (dark)', text, dark, c.dark);
            // The editor highlighter gives the same runs.
            final highlighter = new TextMateInputHighlighter(c.token, TextMateBackend.findSyntax(c.token));
            final rope = Rope.fromStr(text);
            highlighter.update(null, rope, false, null, null);
            final editor = highlighter.styles(new Range(0, rope.len()), HighlightTheme.defaultLight().resolver());
            compareWithTruth(c.sample + ' (editor)', text, editor, c.light);
        }
        assertEquals(40, cases.length);
        assertTrue(lines > 2000, 'compared $lines lines');
    }

    /** Compares the styles of every UTF-16 unit of every line; returns the number of lines. */
    function compareWithTruth(label:String, text:String, runs:Array<StyledRange>, expected:Array<Array<Array<Dynamic>>>):Int {
        final lines = text.split('\n');
        if (lines[lines.length - 1] == '')
            lines.pop();
        assertEquals(expected.length, lines.length, '$label: line count');
        // Style key at each byte.
        final total = haxe.io.Bytes.ofString(text).length;
        final keys:Array<String> = [];
        keys.resize(total);
        for (run in runs) {
            final style = run.style;
            final key = hex(style.color) + '/' + (style.fontStyle == glaze.FontStyle.Italic ? 1 : 0) + '/'
                + (style.fontWeight == null ? 'null' : Std.string(Std.int(style.fontWeight)));
            for (i in run.range.start...run.range.end)
                keys[i] = key;
        }
        var lineStart = 0;
        var failures = 0;
        for (row in 0...lines.length) {
            final line = lines[row];
            final map = utf16ToUtf8(line);
            for (entry in expected[row]) {
                final start:Int = entry[0];
                final end:Int = entry[1];
                final key = entry[2] + '/' + entry[3] + '/' + entry[4];
                for (i in start...end) {
                    final actual = keys[lineStart + map[i]];
                    if (actual != key) {
                        if (failures < 3)
                            assertEquals(key, actual, '$label: line ${row + 1}, column ${i + 1}: ${line}');
                        failures++;
                        break;
                    }
                }
            }
            lineStart += haxe.io.Bytes.ofString(line).length + 1;
        }
        assertEquals(0, failures, '$label: mismatching tokens');
        return lines.length;
    }

    static function utf16ToUtf8(line:String):Array<Int> {
        final map:Array<Int> = [];
        var bytes = 0;
        var i = 0;
        while (i < line.length) {
            map.push(bytes);
            final c = line.charCodeAt(i);
            if (c < 0x80)
                bytes += 1;
            else if (c < 0x800)
                bytes += 2;
            else if (c >= 0xD800 && c <= 0xDBFF) {
                map.push(bytes);
                bytes += 4;
                i++;
            }
            else
                bytes += 3;
            i++;
        }
        map.push(bytes);
        return map;
    }

    // The incremental editor highlighter

    static function edit(rope:Rope, start:Int, end:Int, text:String):InputEdit {
        final startPosition = rope.offsetToPoint(start);
        final oldEndPosition = rope.offsetToPoint(end);
        rope.remove(start, end);
        rope.insert(start, text);
        final newEnd = start + haxe.io.Bytes.ofString(text).length;
        return new InputEdit(start, end, newEnd, startPosition, oldEndPosition, rope.offsetToPoint(newEnd));
    }

    function assertSameAsWholeDocument(label:String, highlighter:TextMateInputHighlighter, rope:Rope, language:String) {
        final whole = TextMateBackend.parse(TextMateBackend.findSyntax(language), rope.toString());
        final incremental = highlighter.highlightsIn(new Range(0, rope.len()));
        assertEquals(whole.join(','), incremental.join(','), label);
    }

    function testEditsOnlyRetokenizeWhatChanged() {
        final samples:haxe.DynamicAccess<String> = haxe.Json.parse(samplesJson());
        final rope = Rope.fromStr(samples.get("rope.rs"));
        final highlighter = new TextMateInputHighlighter("rust", TextMateBackend.findSyntax("rust"));
        highlighter.update(null, rope, true, null, null);
        assertEquals(rope.linesLen(), highlighter.lastTokenizedLines);
        assertTrue(highlighter.foldRanges(rope).length > 0);

        // Typing inside a line retokenizes that line only.
        final at = rope.lineStartOffset(100) + 4;
        highlighter.update(edit(rope, at, at, "x"), rope, true, null, null);
        assertEquals(1, highlighter.lastTokenizedLines);
        assertSameAsWholeDocument("typing", highlighter, rope, "rust");

        // Opening a block comment changes the state of every following line.
        final at2 = rope.lineStartOffset(200);
        highlighter.update(edit(rope, at2, at2, "/*"), rope, true, null, null);
        assertTrue(highlighter.lastTokenizedLines > 100);
        assertSameAsWholeDocument("open comment", highlighter, rope, "rust");

        // Closing it again: lines are retokenized until the state matches.
        final at3 = rope.lineStartOffset(205);
        highlighter.update(edit(rope, at3, at3, "*/\n"), rope, true, null, null);
        assertSameAsWholeDocument("close comment", highlighter, rope, "rust");

        // Removing lines, joining lines, replacing across lines.
        highlighter.update(edit(rope, rope.lineStartOffset(10), rope.lineStartOffset(20), ""), rope, true, null, null);
        assertSameAsWholeDocument("remove lines", highlighter, rope, "rust");
        final join = rope.lineEndOffset(30);
        highlighter.update(edit(rope, join, join + 1, ""), rope, true, null, null);
        assertSameAsWholeDocument("join lines", highlighter, rope, "rust");
        highlighter.update(edit(rope, rope.lineStartOffset(40) + 2, rope.lineStartOffset(43) + 5, "\"é😀\nfn x() {}\n"), rope, true, null,
            null);
        assertSameAsWholeDocument("replace", highlighter, rope, "rust");
        // At the very end, and the whole text.
        highlighter.update(edit(rope, rope.len(), rope.len(), "\n// end"), rope, true, null, null);
        assertSameAsWholeDocument("append", highlighter, rope, "rust");
        highlighter.update(edit(rope, 0, rope.len(), "let a = 1;"), rope, true, null, null);
        assertSameAsWholeDocument("replace all", highlighter, rope, "rust");
        highlighter.update(edit(rope, 0, rope.len(), ""), rope, true, null, null);
        assertEquals(0, highlighter.highlightsIn(new Range(0, 0)).length);
    }

    function testRandomEditsMatchAWholeDocumentTokenization() {
        final samples:haxe.DynamicAccess<String> = haxe.Json.parse(samplesJson());
        var seed = 12345;
        function next(max:Int):Int {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            return max <= 0 ? 0 : seed % max;
        }
        final inserts = ["\n", "\"", "/*", "*/", "{", "}", "'", "x", "é", "`", "# ", "<!--", "-->", "\n\n", "//"];
        for (pair in [["markdown-README.md", "md"], ["embedded.html", "html"], ["demo.py", "python"], ["grammar.ts", "ts"]]) {
            final rope = Rope.fromStr(samples.get(pair[0]));
            final highlighter = new TextMateInputHighlighter(pair[1], TextMateBackend.findSyntax(pair[1]));
            highlighter.update(null, rope, false, null, null);
            for (step in 0...25) {
                var start = rope.charIndexToOffset(next(rope.lenChars()));
                var end = rope.charIndexToOffset(Std.int(Math.min(rope.lenChars(), rope.offsetToCharIndex(start) + next(30))));
                highlighter.update(edit(rope, start, end, next(3) == 0 ? "" : inserts[next(inserts.length)]), rope, false, null, null);
            }
            assertSameAsWholeDocument(pair[0], highlighter, rope, pair[1]);
        }
    }

    /** The folds kept from the changed lines only equal a scan of the whole text (Rust `brace_fold_ranges`) after every edit. */
    function testRandomEditsKeepTheFoldsOfAWholeTextScan() {
        final samples:haxe.DynamicAccess<String> = haxe.Json.parse(samplesJson());
        var seed = 4242;
        function next(max:Int):Int {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            return max <= 0 ? 0 : seed % max;
        }
        final inserts = ["\n", "{", "}", "{\n", "\n}", "}\n{", "\"", "'", "`", "\\", "//", "#", "\r\n", "\r", "{}", "\n\n\n", "x", "é😀", "{\"a\": {\n"];
        var compared = 0;
        var nonEmpty = 0;
        for (pair in [["rope.rs", "rust"], ["grammar.ts", "ts"], ["demo.py", "python"], ["embedded.html", "html"]]) {
            final rope = Rope.fromStr(samples.get(pair[0]));
            final highlighter = new TextMateInputHighlighter(pair[1], TextMateBackend.findSyntax(pair[1]));
            highlighter.update(null, rope, true, null, null);
            for (step in 0...120) {
                final start = rope.charIndexToOffset(next(rope.lenChars() + 1));
                final end = rope.charIndexToOffset(Std.int(Math.min(rope.lenChars(), rope.offsetToCharIndex(start) + next(next(4) == 0 ? 400 : 6))));
                highlighter.update(edit(rope, start, end, next(4) == 0 ? "" : inserts[next(inserts.length)]), rope, true, null, null);
                final expected = TextMateBackend.braceFoldRanges(rope.toString());
                final actual = highlighter.foldRanges(rope);
                assertEquals([for (f in expected) '${f.startLine}-${f.endLine}'].join(','), [for (f in actual) '${f.startLine}-${f.endLine}'].join(','),
                    '${pair[0]} step $step');
                compared++;
                if (expected.length > 0)
                    nonEmpty++;
            }
            // Replacing everything, and emptying
            highlighter.update(edit(rope, 0, rope.len(), "a {\n{\n}\n\n}\n"), rope, true, null, null);
            assertEquals('0-4', [for (f in highlighter.foldRanges(rope)) '${f.startLine}-${f.endLine}'].join(','));
            highlighter.update(edit(rope, 0, rope.len(), ""), rope, true, null, null);
            assertEquals(0, highlighter.foldRanges(rope).length);
        }
        assertEquals(480, compared);
        assertTrue(nonEmpty > 100, 'edits with folds: $nonEmpty');
    }

    #end

    static macro function truthJson():haxe.macro.Expr {
        final file = haxe.macro.Context.getPosInfos(haxe.macro.Context.currentPos()).file;
        final path = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../../data/highlight/truth.json');
        haxe.macro.Context.registerModuleDependency('tests.kit.HighlighterTest', path);
        return macro $v{sys.io.File.getContent(path)};
    }

    static macro function samplesJson():haxe.macro.Expr {
        final file = haxe.macro.Context.getPosInfos(haxe.macro.Context.currentPos()).file;
        final dir = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../../data/highlight/samples');
        final files:haxe.DynamicAccess<String> = {};
        for (name in sys.FileSystem.readDirectory(dir)) {
            if (name == 'NOTICE.md')
                continue;
            final path = dir + '/' + name;
            haxe.macro.Context.registerModuleDependency('tests.kit.HighlighterTest', path);
            files.set(name, sys.io.File.getContent(path));
        }
        return macro $v{haxe.Json.stringify(files)};
    }

    /** The bundled grammar files (JavaScript and C# builds only, see `addGrammars`). */
    static macro function grammarFiles():haxe.macro.Expr {
        final file = haxe.macro.Context.getPosInfos(haxe.macro.Context.currentPos()).file;
        // The plugin root (tests/unit is two levels below it)
        final unit = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../..');
        final pluginRoot = unit + '/../..';
        final dir = haxe.io.Path.normalize(pluginRoot + '/assets/glaze/grammars');
        final files:haxe.DynamicAccess<String> = {};
        for (name in sys.FileSystem.readDirectory(dir)) {
            if (!StringTools.endsWith(name, '.json'))
                continue;
            final path = dir + '/' + name;
            haxe.macro.Context.registerModuleDependency('tests.kit.HighlighterTest', path);
            files.set(name, sys.io.File.getContent(path));
        }
        if (haxe.macro.Context.defined('cs')) {
            // A string literal this large exceeds the C# limit of the user strings
            haxe.macro.Context.addResource('glaze-test-grammars', haxe.io.Bytes.ofString(haxe.Json.stringify(files)));
            return macro haxe.Resource.getString('glaze-test-grammars');
        }
        return macro $v{haxe.Json.stringify(files)};
    }

}

// Ported from gpui-kit 0.8.1: crates/component/src/text/mod.rs, compat.rs, frontmatter.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

#if !macro
import gpui.AbsoluteLength;
import gpui.Context;
import gpui.FontStyle;
import gpui.FontWeight;
import gpui.HighlightStyle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.Window;
import gpui.component.Component;
import gpui.component.text.FrontmatterPlugin;
import gpui.component.text.TextView;
import gpui.component.text.TextViewStyle;
import gpui.component.theme.Theme;
import testing.VisualTestContext;

import gpui.Prelude.*;

private class StatelessMarkdown extends Model implements Render {
    final onRender:Void->Void;

    public function new(onRender:Void->Void) {
        super();
        this.onRender = onRender;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        onRender();
        return div().child(TextView.markdownAt(TextComponentTest.testMarkdown()).markdownBlockParser((_, _) -> null));
    }
}
#end

/**
 * Tests of the component text layer (Rust `component/src/text`): the theme
 * adapter (`mod.rs`), the compatibility `TextView` (`compat.rs`) and the
 * frontmatter plugin (`frontmatter.rs`).
 *
 * Not ported: the code block highlighter tests (tree-sitter and syntect
 * features, wave 11), `legacy_text_view_keeps_element_associated_types`
 * (a Rust type check with no runtime behaviour).
 */
@:access(gpui.component.text)
class TextComponentTest #if !macro extends KitTestCase #end {

    #if !macro

    static function radiusEquals(value:Null<AbsoluteLength>, expected:Float):Bool {
        return switch value {
            case Pixels(px): px == expected;
            case _: false;
        }
    }

    // mod.rs

    function testComponentThemeAdapterMapsTextColorsWithoutHighlighting() {
        final theme = new Theme();
        final style = TextView.baseTextViewStyle(theme);

        assertTrue(style.foreground().equals(theme.foreground));
        assertTrue(style.mutedForeground().equals(theme.mutedForeground));
        assertTrue(style.link().equals(theme.link));
        assertTrue(style.selection().equals(theme.selection));
        assertTrue(style.inlineCode().backgroundColor.equals(theme.accent));
        final radius = theme.semanticTokens().radius.md;
        assertTrue(radiusEquals(style.table().cornerRadiusTopLeft, radius));
        assertTrue(radiusEquals(style.table().cornerRadiusTopRight, radius));
        assertTrue(radiusEquals(style.table().cornerRadiusBottomLeft, radius));
        assertTrue(radiusEquals(style.table().cornerRadiusBottomRight, radius));
    }

    function testComponentTextViewTableRespectsSquareBaseRadiusToken() {
        final theme = new Theme();
        theme.radius = 0.;

        final style = TextView.baseTextViewStyle(theme);
        assertTrue(radiusEquals(style.table().cornerRadiusTopLeft, 0.));
        assertTrue(radiusEquals(style.table().cornerRadiusTopRight, 0.));
        assertTrue(radiusEquals(style.table().cornerRadiusBottomLeft, 0.));
        assertTrue(radiusEquals(style.table().cornerRadiusBottomRight, 0.));
    }

    function testTextViewBuilder() {
        // Rust also sets `style.highlight_theme` (wave 11).
        final style = TextViewStyle.defaultValue();
        final view:TextView = TextView.markdownAt('# compatible')
            .withStyle(style)
            .selectable(true)
            .scrollable(true)
            .imageSource(uri -> gpui.ImageSource.Resource(gpui.Resource.Path(uri)));
        assertTrue(view != null);
    }

    function testLegacyDefaultStyleKeepsActiveComponentThemeColors() {
        final theme = new Theme();
        theme.foreground = rgb(0xf4f4f5).toHsla();
        theme.link = rgb(0x38bdf8).toHsla();
        theme.selection = rgba(0x2563eb66).toHsla();

        final style = TextView.resolveComponentStyle(theme, TextViewStyle.defaultValue());

        assertTrue(style.foreground().equals(theme.foreground));
        assertTrue(style.link().equals(theme.link));
        assertTrue(style.selection().equals(theme.selection));
    }

    function testLegacyTableRefinementKeepsComponentRadius() {
        final theme = new Theme();
        final table = new StyleRefinement();
        table.overflowX = Scroll;

        final style = TextView.resolveComponentStyle(theme, TextViewStyle.defaultValue().withTable(table));

        final radius = theme.semanticTokens().radius.md;
        assertTrue(radiusEquals(style.table().cornerRadiusTopLeft, radius));
        assertTrue(radiusEquals(style.table().cornerRadiusTopRight, radius));
        assertTrue(radiusEquals(style.table().cornerRadiusBottomLeft, radius));
        assertTrue(radiusEquals(style.table().cornerRadiusBottomRight, radius));
        assertEquals(gpui.Overflow.Scroll, style.table().overflowX);
    }

    function testLegacyPartialStylesRefineComponentThemeDefaults() {
        final theme = new Theme();
        final tableHead = new StyleRefinement();
        tableHead.text = new gpui.TextStyleRefinement();
        tableHead.text.fontWeight = FontWeight.BOLD;
        final inlineCode = new HighlightStyle(null, null, FontStyle.Italic);

        final style = TextView.resolveComponentStyle(theme, TextViewStyle.defaultValue().withTableHead(tableHead).withInlineCode(inlineCode));

        final background = style.tableHead().background;
        assertTrue(background != null && background.solid.equals(theme.tableHead));
        assertTrue(style.tableHead().text.color.equals(theme.tableHeadForeground));
        assertEquals(FontWeight.BOLD, style.tableHead().text.fontWeight);
        assertTrue(style.inlineCode().backgroundColor.equals(theme.accent));
        assertEquals(FontStyle.Italic, style.inlineCode().fontStyle);
    }

    function testLegacyHeadingConfigurationMapsToBaseHeadingRefinements() {
        final theme = new Theme();
        final legacy = TextViewStyle.defaultValue();
        legacy.headingBaseFontSize = 10.;
        legacy.headingFontSize = (level, base) -> base * level;

        final style = TextView.resolveComponentStyle(theme, legacy);

        assertTrue(style.heading(2).equals(StyleBuilder.build(s -> s.textSize(px(20.)))));
    }

    // compat.rs

    function testStatelessMarkdownFacadeSettlesAfterParsing() {
        app.update(cx -> {
            Component.init(cx);
            // The test fonts have no `Menlo` (the macOS monospace family of the theme).
            gpui.base.theme.Theme.globalMut(cx).tokens.typography.mono = 'JetBrains Mono';
        });
        var renders = 0;
        final result = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new StatelessMarkdown(() -> renders++));
        final cx = result.cx;

        cx.runUntilParked();
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
        final rendersAfterRedraw = renders;
        cx.runUntilParked();
        assertEquals(rendersAfterRedraw, renders, 'an unchanged compatibility TextView must not schedule another render after its parse');
        cx.destroy();
    }

    // frontmatter.rs

    function testParsesPlainMappingAsMetadata() {
        final frontmatter = FrontmatterPlugin.parseFrontmatter("name: gpui-component-dev\ndescription: Contributing to `crates/ui`.");
        assertTrue(frontmatter != null, 'frontmatter mapping');

        assertEquals(2, frontmatter.entries.length);
        assertEquals('name', frontmatter.entries[0].key);
        assertEquals('gpui-component-dev', frontmatter.entries[0].value);
        assertEquals('Contributing to `crates/ui`.', frontmatter.entries[1].value);
    }

    function testParsesBlockScalars() {
        final frontmatter = FrontmatterPlugin.parseFrontmatter("description: >-\n  First line\n  second line.\nnotes: |-\n  # literal content\n\n  second line");
        assertTrue(frontmatter != null, 'frontmatter mapping');

        assertEquals('First line second line.', frontmatter.entries[0].value);
        assertEquals('# literal content\n\nsecond line', frontmatter.entries[1].value);
    }

    function testPreservesBlankLinesInFoldedScalars() {
        final frontmatter = FrontmatterPlugin.parseFrontmatter("description: >-\n  First paragraph.\n\n  Second paragraph.");
        assertTrue(frontmatter != null, 'frontmatter mapping');

        assertEquals('First paragraph.\nSecond paragraph.', frontmatter.entries[0].value);
    }

    function testPreservesIndentedHashesInFoldedScalars() {
        final frontmatter = FrontmatterPlugin.parseFrontmatter("description: >-\n  First line\n  # not a comment\n  last line");
        assertTrue(frontmatter != null, 'frontmatter mapping');

        assertEquals('First line # not a comment last line', frontmatter.entries[0].value);
    }

    function testRejectsNestedMappings() {
        assertTrue(FrontmatterPlugin.parseFrontmatter("config:\n  theme: dark") == null);
    }

    function testRejectsNonMappingYaml() {
        assertTrue(FrontmatterPlugin.parseFrontmatter("- name: example") == null);
    }

    function testPreservesLiteralScalarWhitespace() {
        final parsed = FrontmatterPlugin.parseFrontmatter("notes: |-\n\n  first  \n    indented\n    \n  last\n\n");
        assertTrue(parsed != null, 'literal scalar');
        assertEquals('\nfirst  \n  indented\n  \nlast', parsed.entries[0].value);
    }

    function testRejectsUnsupportedScalarSyntax() {
        for (source in [
            "title: Hello # comment",
            "title: \"Hello\\nworld\"",
            "title: 'Hello'",
            "tags: [one, two]",
            "config: {theme: dark}",
            "value: &anchor hello",
            "value: *anchor",
            "value: !!str hello",
            "value: a: b",
            "notes: >-\n  first\n    indented\n  last",
            "notes: |-\n    first\n  invalid indentation",
            "notes: |2-\n  text",
            "notes: |\n  text",
            "notes: >+\n  text",
        ]) {
            assertTrue(FrontmatterPlugin.parseFrontmatter(source) == null, haxe.Json.stringify(source));
        }
    }

    function testPreservesPlainScalarPunctuation() {
        final parsed = FrontmatterPlugin.parseFrontmatter("url: https://example.com/#section\nvalue: -42");
        assertTrue(parsed != null, 'plain values');
        assertEquals('https://example.com/#section', parsed.entries[0].value);
        assertEquals('-42', parsed.entries[1].value);
    }

    #end

    /** `examples/fixtures/test.md` of gpui-kit (copied to `test/unit/data/text/test.md`). */
    public static macro function testMarkdown():haxe.macro.Expr {
        final file = haxe.macro.Context.getPosInfos(haxe.macro.Context.currentPos()).file;
        final path = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../../data/text/test.md');
        haxe.macro.Context.registerModuleDependency('tests.kit.TextComponentTest', path);
        return macro $v{sys.io.File.getContent(path)};
    }

}

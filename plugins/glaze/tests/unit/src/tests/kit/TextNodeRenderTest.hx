// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.FontStyle;
import glaze.FontWeight;
import glaze.Range;
import glaze.TestDispatcher;
import glaze.kit.base.text.InlineFlow.InlineFlowItem;
import glaze.kit.base.text.InlineNode;
import glaze.kit.base.text.LinkMark;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.NodeContext;
import glaze.kit.base.text.NodeRender;
import glaze.kit.base.text.Paragraph;
import glaze.kit.base.text.RangedMark;
import glaze.kit.base.text.TextMark;
import glaze.kit.base.theme.Theme;
import glaze.AbsoluteLength;
import glaze.HighlightStyle;
import glaze.StyleBuilder;
import glaze.TextStyle;
import glaze.TextStyleRefinement;
import glaze.kit.base.text.BlockNode;
import glaze.kit.base.text.ColumnumnAlign;
import glaze.kit.base.text.InlineElement;
import glaze.kit.base.text.MarkdownExtensions;
import glaze.kit.base.text.NodeRenderOptions;
import glaze.kit.base.text.Table;
import glaze.kit.base.text.Table.TableCell;
import glaze.kit.base.text.Table.TableColumnWidths;
import glaze.kit.base.text.Table.TableRow;
import glaze.kit.base.text.TextUtils;
import glaze.kit.base.text.TextViewStyle;
import glaze.kit.base.text.format.MarkdownFormat;
import tests.kit.TextInlineTest.TextTestDraw;
import tests.kit.TextInlineTest.TextTestFonts;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.AbsoluteLengthTools;
using glaze.kit.base.text.BlockNode.BlockNodeTools;

/**
 * The tests of node.rs that render or measure blocks in a window.
 */
@:access(glaze.kit.base.text)
class TextNodeRenderTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function openEmpty():VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> div()));
        contexts.push(opened.cx);
        return opened.cx;
    }

    static inline final CELL_PAD_PX:Float = 24.0;
    static inline final CELL_MIN_PX:Float = 48.0;
    static inline final CELL_BORDER_PX:Float = 1.0;

    static function plainCell(text:String):TableCell {
        return new TableCell(glaze.kit.base.text.Paragraph.ofText(text));
    }

    static function tableOf(rows:Array<Array<TableCell>>, columnAligns:Array<ColumnumnAlign>):Table {
        final table = new Table();
        table.children = [for (children in rows) new TableRow(children)];
        table.columnAligns_ = columnAligns;
        return table;
    }

    static function cachedColumnWidths(table:Table):TableColumnWidths {
        return table.columnWidthsCache;
    }

    static function codeParagraph(code:String):glaze.kit.base.text.Paragraph {
        final paragraph = new glaze.kit.base.text.Paragraph();
        paragraph.push(new InlineNode(code).marks([new RangedMark(new Range(0, TextUtils.len(code)), new TextMark().withCode())]));
        return paragraph;
    }

    static function styleOf(family:String, fontSize:AbsoluteLength):TextStyle {
        final style = new TextStyle();
        style.fontFamily = family;
        style.fontSize = fontSize;
        return style;
    }

    function testTableColumnUsesPreparedInlineMetricsAfterResourceUpdate() {
        final app = TextTestDraw.testApp();
        var width = 400;
        final nodeCx = new NodeContext();
        nodeCx.markdownExtensions = new MarkdownExtensions().plugin(new TextTestInlinePlugin('test').renderWith((_, _, _, _) -> {
            return new InlineElement(img(glaze.Image.fromBytes(glaze.ImageFormat.Svg, haxe.io.Bytes.ofString('<svg/>'))).w(px(width)).h(px(20.)))
                .withBaseline(15.);
        }));
        final custom = new glaze.kit.base.text.Paragraph();
        custom.children_ = [InlineNode.ofCustom(new MarkdownNode('test', null).text('x'))];
        final table = tableOf([[plainCell('ordinary text')], [new TableCell(custom)]], []);
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            var cached:Null<TableColumnWidths> = null;
            for (expected in [400, 600, 10, 400]) {
                width = expected;
                final measured = NodeRender.measureTableColumns(table, 1, nodeCx, window, cx)[0];
                final current = cachedColumnWidths(table);
                assertEquals(Math.max(current.widths[0], expected + CELL_PAD_PX), measured);
                assertEquals('1,0', current.customCells.map(c -> c.join(',')).join(';'));
                if (cached != null)
                    assertTrue(cached == current);
                cached = current;
            }
            return null;
        });
    }

    function testBlockquoteTypographyReachesNestedTableMeasurement() {
        final quote = BlockNode.Blockquote([BlockNode.Table(tableOf([[plainCell('0123456789')]], []))], null);
        final app = TextTestDraw.wideMonoApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            cx.setGlobal(new Theme(), Theme);
            window.withTextStyle(StyleBuilder.build(s -> s.fontFamily(TextTestFonts.BODY).textSize(px(15.))).text, window -> {
                for (item in [
                    {refinement: new glaze.StyleRefinement(), expected: 94.},
                    {
                        refinement: StyleBuilder.build(s -> s.fontFamily(TextTestFonts.MONO).textSize(px(30.)).fontWeight(FontWeight.BOLD)),
                        expected: 199.
                    }
                ]) {
                    final nodeCx = new NodeContext();
                    nodeCx.style = TextViewStyle.defaultValue().withBlockquoteStyle(item.refinement);
                    nodeCx.bodyFontSize = 15.;
                    quote.renderBlock(new NodeRenderOptions(), nodeCx, window, cx);
                    final table = switch quote {
                        case Blockquote(children, _): switch children[0] {
                                case Table(table): table;
                                case _: null;
                            }
                        case _: null;
                    }
                    // Ten glyphs at the table's 14px size, plus 24px cell padding.
                    assertEquals(Std.string([item.expected]), Std.string(cachedColumnWidths(table).widths));
                }
                return null;
            });
            return null;
        });
    }

    function testTableColumnsCachePreservesPlainWidthsAndClones() {
        final long = TextUtils.repeat("é界", 2048);
        final table = tableOf([
            [plainCell(' \t$long \nshort\n '), plainCell('')],
            [plainCell('short')],
            [],
            [plainCell(''), plainCell('a\nabcdefghijklmnop')]
        ], []);
        final uncached = table.clone();
        final nodeCx = new NodeContext();
        final app = TextTestDraw.wideMonoApp();
        var cached:Null<TableColumnWidths> = null;
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            window.setRemSize(20.);
            final style = styleOf(TextTestFonts.BODY, Rems(1.));
            cached = window.withTextStyle(style.subtract(new TextStyleRefinement()), window -> {
                final recorded = TextTestFonts.recordShapedLines(() -> NodeRender.measureTableColumns(table, 2, nodeCx, window, cx));
                final widths = recorded.result;
                assertEquals(Std.string([40960. + CELL_PAD_PX + CELL_BORDER_PX, 184.]), Std.string(widths));
                assertTrue(recorded.shapedLines.indexOf(long) >= 0);
                assertTrue(table.equals(uncached), "derived widths do not change table equality");
                assertNull(uncached.columnWidthsCache);

                final cached = cachedColumnWidths(table);
                final cloned = table.clone();
                for (same in [table, cloned]) {
                    final again = TextTestFonts.recordShapedLines(() -> NodeRender.measureTableColumns(same, 2, nodeCx, window, cx));
                    assertEquals(Std.string(widths), Std.string(again.result));
                    assertEquals(0, again.shapedLines.length);
                    assertTrue(cached == cachedColumnWidths(same));
                }

                // A different column count changes which cells draw borders.
                assertEquals(Std.string([widths[0], widths[1] + CELL_BORDER_PX, CELL_MIN_PX]),
                    Std.string(NodeRender.measureTableColumns(cloned, 3, nodeCx, window, cx)));
                assertFalse(cached == cachedColumnWidths(cloned));
                assertTrue(cached == cachedColumnWidths(table));
                assertEquals(0, NodeRender.measureTableColumns(new Table(), 0, nodeCx, window, cx).length);
                return cached;
            });
            return null;
        });
        // A parsed table can be rendered in another window. Do not reuse a
        // pixel-width cache from a different window's text system.
        final other = TextTestDraw.wideMonoApp();
        TextTestDraw.inPrepaint(other, (window, cx) -> {
            window.setRemSize(cached.remSize);
            window.withTextStyle(cached.textStyles.body.subtract(new TextStyleRefinement()), window -> {
                NodeRender.measureTableColumns(table, 2, nodeCx, window, cx);
                assertFalse(cached == cachedColumnWidths(table));
                return null;
            });
            return null;
        });
    }

    function testTableColumnsCacheTracksTypography() {
        final code = "0123456789";
        final table = tableOf([[plainCell(code), new TableCell(codeParagraph(code))]], []);
        final base = styleOf(TextTestFonts.BODY, Rems(1.));
        final larger = base.clone();
        larger.fontSize = Rems(2.);
        final bold = base.clone();
        bold.fontWeight = FontWeight.BOLD;
        final mono = base.clone();
        mono.fontFamily = TextTestFonts.MONO;
        final normalCode = new HighlightStyle();
        final boldCode = HighlightStyle.ofFontWeight(FontWeight.BOLD);
        final app = TextTestDraw.wideMonoApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            var previous:Null<TableColumnWidths> = null;
            for (item in [
                {style: base, rem: 20., family: TextTestFonts.MONO, code: normalCode, expected: [125., 207.]},
                {style: base, rem: 30., family: TextTestFonts.MONO, code: normalCode, expected: [175., 294.5]},
                {style: larger, rem: 20., family: TextTestFonts.MONO, code: normalCode, expected: [225., 382.]},
                {style: bold, rem: 20., family: TextTestFonts.MONO, code: normalCode, expected: [175., 250.75]},
                {style: mono, rem: 20., family: TextTestFonts.MONO, code: normalCode, expected: [225., 207.]},
                {style: base, rem: 20., family: TextTestFonts.MONO, code: normalCode, expected: [125., 207.]},
                {style: base, rem: 20., family: TextTestFonts.BODY, code: normalCode, expected: [125., 119.5]},
                {style: base, rem: 20., family: TextTestFonts.MONO, code: normalCode, expected: [125., 207.]},
                {style: base, rem: 20., family: TextTestFonts.MONO, code: boldCode, expected: [125., 250.75]}
            ]) {
                final theme = new Theme();
                theme.tokens.typography.mono = item.family;
                cx.setGlobal(theme, Theme);
                window.setRemSize(item.rem);
                final nodeCx = new NodeContext();
                nodeCx.style = TextViewStyle.defaultValue().withInlineCode(item.code);
                window.withTextStyle(item.style.subtract(new TextStyleRefinement()), window -> {
                    final widths = NodeRender.measureTableColumns(table, 2, nodeCx, window, cx);
                    for (i in 0...widths.length) {
                        assertTrue(Math.abs(widths[i] - item.expected[i]) < 0.01, '${widths[i]} != ${item.expected[i]}');
                    }
                    final cached = cachedColumnWidths(table);
                    if (previous != null)
                        assertFalse(previous == cached);
                    previous = cached;
                    assertEquals(Std.string(widths), Std.string(NodeRender.measureTableColumns(table, 2, nodeCx, window, cx)));
                    assertTrue(cached == cachedColumnWidths(table));
                    return null;
                });
            }
            return null;
        });
    }

    function testTableColumnsCacheIsRebuiltForReparsedTables() {
        final nodeCx = new NodeContext();
        final app = TextTestDraw.wideMonoApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            final style = styleOf(TextTestFonts.BODY, Pixels(20.));
            window.withTextStyle(style.subtract(new TextStyleRefinement()), window -> {
                var previous:Null<TableColumnWidths> = null;
                for (item in [{text: "longer cell", expected: 134.}, {text: "x", expected: CELL_MIN_PX}]) {
                    final source = '| h |\n| - |\n| ${item.text} |\n';
                    final document = MarkdownFormat.parse(source, nodeCx);
                    final table = switch document.blocks[0] {
                        case Table(table): table;
                        case _: null;
                    }
                    assertNotNull(table, "expected a parsed table");
                    assertNull(table.columnWidthsCache);
                    assertEquals(Std.string([item.expected]), Std.string(NodeRender.measureTableColumns(table, 1, nodeCx, window, cx)));
                    final cached = cachedColumnWidths(table);
                    if (previous != null)
                        assertFalse(previous == cached);
                    previous = cached;
                    assertEquals(source, document.source);
                }
                return null;
            });
            return null;
        });
    }

    /**
     * Table columns are sized from shaped text, so a column of inline code
     * has to be measured in the code family. Measured in the body font, the
     * wide-mono test font makes the width come out at half the rendered
     * width.
     */
    function testTableColumnOfInlineCodeCellsFitsTheMonoWidth() {
        final code = "method_name()";
        final table = tableOf([[new TableCell(codeParagraph(code))]], []);
        final nodeCx = new NodeContext();

        final app = TextTestDraw.wideMonoApp();
        final result = TextTestDraw.inPrepaint(app, (window, cx) -> {
            final theme = new Theme();
            theme.tokens.typography.mono = TextTestFonts.MONO;
            cx.setGlobal(theme, Theme);
            final fontSize:Float = window.textStyle().fontSize.toPixels(window.remSize());
            return {colW: NodeRender.measureTableColumns(table, 1, nodeCx, window, cx), fontSize: fontSize};
        });

        final monoW = TextTestFonts.widthOf(code, TextTestFonts.MONO, TextTestFonts.f32(result.fontSize * 0.875));
        assertTrue(Math.abs(result.colW[0] - (monoW + CELL_PAD_PX + glaze.kit.base.text.InlineFlow.INLINE_CODE_PADDING * 2.)) < 0.01,
            'colW ${result.colW[0]} must fit the mono width $monoW plus padding $CELL_PAD_PX');
    }

    function testCustomInlineInheritsMarksAndResolvesLinkReferences() {
        final window = openEmpty();
        window.update((_, cx) -> {
            cx.setGlobal(new Theme(), Theme);
            final nodeCx = new NodeContext();
            final mark = new TextMark().withBold();
            mark.italic = true;
            mark.strikethrough = true;
            mark.link = new LinkMark('', 'ref');
            nodeCx.linkRefs.set('ref', new LinkMark('https://example.com'));
            final paragraph = new Paragraph();
            paragraph.children_ = [InlineNode.ofCustom(new MarkdownNode('test', null).text('x')).marks([new RangedMark(new Range(0, 1), mark)])];
            final items = NodeRender.inlineFlowItems(paragraph, null, [], [], nodeCx, cx);
            switch items[0] {
                case Object(_, _, _, _, _, style, link):
                    assertEquals(FontWeight.BOLD, style.fontWeight);
                    assertEquals(FontStyle.Italic, style.fontStyle);
                    assertNotNull(style.strikethrough);
                    assertEquals('https://example.com', link.url);
                case _:
                    assertTrue(false, 'expected an object item');
            }
            return null;
        });
    }

}

package tests;

import glaze.DecorationRun;
import glaze.Font;
import glaze.FontId;
import glaze.HeadlessAtlas;
import glaze.Hsla;
import glaze.IndexResult;
import glaze.LineLayout;
import glaze.LineLayoutCache;
import glaze.LinePaint;
import glaze.NoopTextSystem;
import glaze.Point;
import glaze.ShapedGlyph;
import glaze.ShapedLine;
import glaze.ShapedRun;
import glaze.Size;
import glaze.TextPainter;
import glaze.TextSystem;
import glaze.UnderlineStyle;
import glaze.WindowTextSystem;
import glaze.WrapBoundary;
import glaze.WrappedLine;
import glaze.WrappedLineLayout;
import glaze.scene.Scene;
import testing.TestCase;

/**
 * Tests of line layouts (gpui-pre 0.3.10: src/text_system/line_layout.rs,
 * src/text_system/line.rs):
 *
 * - shaping, hit testing and wrapping compared with the original GPUI
 *   (`CosmicTextSystem`, see `TextFixtures`);
 * - the `#[cfg(test)]` tests of both files.
 */
class LineLayoutTest extends TestCase {

    /**
     * Tolerance on glyph positions: GPUI (cosmic-text) accumulates advances
     * in f32, the port in f64.
     */
    static inline final POSITION_EPSILON = 5e-4;

    public static final maxErrors:Map<String, Float> = new Map();

    static function record(category:String, error:Float):Void {
        final current = maxErrors.get(category);
        if (current == null || error > current)
            maxErrors.set(category, error);
    }

    function assertClose(expected:Float, actual:Float, category:String, message:String, ?pos:haxe.PosInfos) {
        record(category, Math.abs(expected - actual));
        assertFloatEquals(expected, actual, POSITION_EPSILON, message, pos);
    }

    function compareLayout(expected:Dynamic, layout:LineLayout, label:String):Bool {
        final before = failures.length;
        assertClose(expected.width, layout.width, 'line width', '$label width');
        assertClose(expected.ascent, layout.ascent, 'ascent / descent', '$label ascent');
        assertClose(expected.descent, layout.descent, 'ascent / descent', '$label descent');
        assertEquals((expected.len:Int), layout.len, '$label len');
        final runs:Array<Dynamic> = expected.runs;
        assertEquals(runs.length, layout.runs.length, '$label run count');
        if (runs.length != layout.runs.length) {
            trace('$label: expected runs ${[for (r in runs) r.family + ':' + (r.glyphs:Array<Dynamic>).length]}, got ${[for (r in layout.runs) TextFixtures.familyOf(r.fontId) + ':' + r.glyphs.length]}');
            return false;
        }
        for (r in 0...runs.length) {
            final run = layout.runs[r];
            assertEquals((runs[r].family:String), TextFixtures.familyOf(run.fontId), '$label run $r family');
            final glyphs:Array<Array<Dynamic>> = runs[r].glyphs;
            assertEquals(glyphs.length, run.glyphs.length, '$label run $r glyph count');
            if (glyphs.length != run.glyphs.length) {
                trace('$label: expected ${[for (g in glyphs) g[0] + '@' + g[3]]}, got ${[for (g in run.glyphs) g.id + '@' + g.index]}');
                continue;
            }
            for (i in 0...glyphs.length) {
                final g = glyphs[i];
                final glyph = run.glyphs[i];
                assertEquals((g[0]:Int), (glyph.id:Int), '$label glyph $i id');
                assertClose(g[1], glyph.position.x, 'glyph x', '$label glyph $i x');
                assertClose(g[2], glyph.position.y, 'glyph y', '$label glyph $i y');
                assertEquals((g[3]:Int), glyph.index, '$label glyph $i index');
                assertEquals((g[4]:Bool), glyph.isEmoji, '$label glyph $i emoji');
            }
        }
        return failures.length == before;
    }

/// Against GPUI

    function testLayoutsMatchGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final windowTs = new WindowTextSystem(TextFixtures.textSystem());
        final cases:Array<Dynamic> = ref.layouts;
        var matching = 0;
        for (c in cases) {
            final text:String = c.text;
            final layout = windowTs.layoutLine(text, c.size, TextFixtures.textRuns(c.runs));
            final label = 'layout "$text" at ${c.size}';
            if (compareLayout(c.layout, layout, label))
                matching++;
        }
        trace('LineLayoutTest: ${matching}/${cases.length} line layouts match GPUI');
    }

    function testHitTestingMatchesGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final windowTs = new WindowTextSystem(TextFixtures.textSystem());
        final cases:Array<Dynamic> = ref.layouts;
        var count = 0;
        for (c in cases) {
            final text:String = c.text;
            final layout = windowTs.layoutLine(text, c.size, TextFixtures.textRuns(c.runs));
            final h:Dynamic = c.hit_testing;
            for (entry in (h.index_for_x:Array<Array<Dynamic>>)) {
                // GPUI's width is an f32 sum: x samples taken exactly at the width are on the edge
                if (Math.abs((entry[0]:Float) - (layout.width:Float)) < POSITION_EPSILON)
                    continue;
                assertEquals((entry[1]:Null<Int>), layout.indexForX(entry[0]), '"$text" index_for_x(${entry[0]})');
                count++;
            }
            for (entry in (h.closest_index_for_x:Array<Array<Dynamic>>)) {
                assertEquals((entry[1]:Int), layout.closestIndexForX(entry[0]), '"$text" closest_index_for_x(${entry[0]})');
                count++;
            }
            for (entry in (h.x_for_index:Array<Array<Dynamic>>)) {
                assertClose(entry[1], layout.xForIndex(entry[0]), 'x_for_index', '"$text" x_for_index(${entry[0]})');
                count++;
            }
        }
        trace('LineLayoutTest: $count hit testing samples compared with GPUI');
    }

    function testForceWidthMatchesGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final windowTs = new WindowTextSystem(TextFixtures.textSystem());
        final f:Dynamic = ref.force_width;
        final text:String = f.text;
        final runs = [new glaze.TextRun(glaze.util.Utf8.byteLength(text), Font.of('JetBrains Mono'), new Hsla(0, 0, 0, 1))];
        final layout = windowTs.layoutLine(text, f.size, runs, f.force_width);
        compareLayout(f.layout, layout, 'force width "$text"');
    }

    static function resultEquals(expected:Dynamic, actual:IndexResult):Bool {
        return switch actual {
            case Ok(index): expected.ok != null && (expected.ok:Int) == index;
            case Err(index): expected.err != null && (expected.err:Int) == index;
        }
    }

    function testWrappedLinesMatchGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final windowTs = new WindowTextSystem(TextFixtures.textSystem());
        final cases:Array<Dynamic> = ref.wraps;
        var matching = 0;
        for (c in cases) {
            final before = failures.length;
            final text:String = c.text;
            final lineHeight:Float = c.line_height;
            final clamp:Int = c.line_clamp != null ? c.line_clamp : -1;
            final lines = windowTs.shapeText(text, c.size, TextFixtures.textRuns(c.runs), c.wrap_width, clamp);
            final expectedLines:Array<Dynamic> = c.lines;
            final label = 'wrap "${text.substr(0, 24)}" at ${c.wrap_width}${clamp >= 0 ? ' clamp ' + clamp : ''}';
            assertEquals(expectedLines.length, lines.length, '$label line count');
            if (expectedLines.length != lines.length)
                continue;
            for (l in 0...lines.length) {
                final e = expectedLines[l];
                final line = lines[l];
                assertEquals((e.text:String), line.text, '$label line $l text');
                assertEquals((e.len:Int), line.len(), '$label line $l len');
                final expectedBoundaries:Array<Array<Int>> = e.wrap_boundaries;
                final boundaries = line.wrapBoundaries();
                final expectedString = [for (b in expectedBoundaries) '${b[0]}:${b[1]}'].join(' ');
                final actualString = [for (b in boundaries) '${b.runIx}:${b.glyphIx}'].join(' ');
                assertEquals(expectedString, actualString, '$label line $l wrap boundaries');
                assertClose(e.width, line.width(), 'wrapped width', '$label line $l width');
                compareLayout(e.layout, line.unwrappedLayout(), '$label line $l');
                if (expectedString != actualString)
                    continue;
                for (p in (e.position_for_index:Array<Array<Dynamic>>)) {
                    final position = line.positionForIndex(p[0], lineHeight);
                    if (p[1] == null) {
                        assertNull(position, '$label position_for_index(${p[0]})');
                    }
                    else {
                        final xy:Array<Float> = p[1];
                        assertNotNull(position, '$label position_for_index(${p[0]})');
                        if (position != null) {
                            assertClose(xy[0], position.x, 'position_for_index', '$label position_for_index(${p[0]}).x');
                            assertClose(xy[1], position.y, 'position_for_index', '$label position_for_index(${p[0]}).y');
                        }
                    }
                }
                for (p in (e.index_for_position:Array<Array<Dynamic>>)) {
                    final position = new Point(p[0], p[1]);
                    final index = line.indexForPosition(position, lineHeight);
                    assertTrue(resultEquals(p[2], index), '$label index_for_position(${p[0]}, ${p[1]}): expected ${haxe.Json.stringify(p[2])}, got $index');
                    final closest = line.closestIndexForPosition(position, lineHeight);
                    assertTrue(resultEquals(p[3], closest), '$label closest_index_for_position(${p[0]}, ${p[1]}): expected ${haxe.Json.stringify(p[3])}, got $closest');
                }
            }
            if (failures.length == before)
                matching++;
        }
        trace('LineLayoutTest: ${matching}/${cases.length} wrapped texts match GPUI (boundaries, layouts, positions)');
    }

    function testReport() {
        testLayoutsMatchGpui();
        testWrappedLinesMatchGpui();
        final keys = [for (k in maxErrors.keys()) k];
        keys.sort((a, b) -> a < b ? -1 : 1);
        for (k in keys)
            trace('LineLayoutTest: max difference with GPUI, $k: ${maxErrors.get(k)}');
    }

/// Ported #[cfg(test)] tests of line_layout.rs

    static function glyphAt(x:Float, index:Int):ShapedGlyph {
        return new ShapedGlyph(0, new Point(x, 0), index, false);
    }

    static function makeLayout(glyphs:Array<ShapedGlyph>):LineLayout {
        return new LineLayout(16, 100, 12, 4, [new ShapedRun(0, glyphs)], 0);
    }

    static function glyphXPositions(layout:LineLayout):String {
        return [for (g in layout.runs[0].glyphs) g.position.x].join(',');
    }

    function testForceWidthLatinUnchanged() {
        final layout = makeLayout([glyphAt(0, 0), glyphAt(8, 1), glyphAt(16, 2)]);
        LineLayoutCache.applyForceWidthToLayout(layout, 8);
        assertEquals('0,8,16', glyphXPositions(layout));
    }

    function testForceWidthCombiningMarksNotAdvanced() {
        // Simulates Thai, base consonant at x=0, combining vowel also at x=0
        final layout = makeLayout([glyphAt(0, 0), glyphAt(0, 3)]);
        LineLayoutCache.applyForceWidthToLayout(layout, 8);
        assertEquals('0,0', glyphXPositions(layout));
    }

    function testForceWidthBaseAfterCombiningMark() {
        final layout = makeLayout([glyphAt(0, 0), glyphAt(0, 3), glyphAt(8, 6)]);
        LineLayoutCache.applyForceWidthToLayout(layout, 8);
        assertEquals('0,0,8', glyphXPositions(layout));
    }

    function testForceWidthMultipleCombiningMarks() {
        final layout = makeLayout([glyphAt(0, 0), glyphAt(0, 3), glyphAt(0, 6), glyphAt(8, 9)]);
        LineLayoutCache.applyForceWidthToLayout(layout, 8);
        assertEquals('0,0,0,8', glyphXPositions(layout));
    }

    function testForceWidthCorrectsDriftedBasePositions() {
        // Font metrics don't perfectly match cell grid: glyphs drift >1px from cell boundary
        final layout = makeLayout([glyphAt(0.5, 0), glyphAt(10.2, 1), glyphAt(19.8, 2)]);
        LineLayoutCache.applyForceWidthToLayout(layout, 8);
        assertEquals('0.5,8,16', glyphXPositions(layout));
    }

    function testForceWidthCombiningMarkAfterWithinToleranceBase() {
        final layout = makeLayout([glyphAt(0.5, 0), glyphAt(0.5, 3)]);
        LineLayoutCache.applyForceWidthToLayout(layout, 8);
        assertEquals('0.5,0.5', glyphXPositions(layout));
    }

/// Ported #[cfg(test)] tests of line.rs

    /** Builds a ShapedLine from (byte_index, x_position) pairs, without a text system. */
    static function makeShapedLine(text:String, glyphs:Array<Array<Float>>, width:Float, decorations:Array<DecorationRun>):ShapedLine {
        final shapedGlyphs = [for (g in glyphs) new ShapedGlyph(0, new Point(g[1], 0), Std.int(g[0]), false)];
        return new ShapedLine(new LineLayout(16, width, 12, 4, [new ShapedRun(0, shapedGlyphs)], glaze.util.Utf8.byteLength(text)), text, decorations);
    }

    function testAlignedLinePaintBounds() {
        final line = makeShapedLine('abcd', [[0, 0], [1, 10], [2, 20], [3, 30]], 40, []);
        final origin = new Point(10, 20);
        final lineHeight = 16.0;
        final cases:Array<Array<Dynamic>> = [
            [false, null, [[10., 50.], [10., 50.], [10., 50.]]],
            [true, null, [[10., 50.], [10., 50.], [10., 50.]]],
            [false, 40., [[10., 50.], [10., 50.], [10., 50.]]],
            [true, 40., [[10., 50.], [10., 50.], [10., 50.]]],
            [false, 100., [[10., 50.], [10., 80.], [10., 110.]]],
            [true, 100., [[10., 50.], [10., 70.], [10., 110.]]],
            [false, 10., [[10., 50.], [-5., 50.], [-20., 50.]]],
            [true, 10., [[10., 50.], [5., 50.], [0., 50.]]],
            [false, 0., [[10., 50.], [-10., 50.], [-30., 50.]]],
            [true, 0., [[10., 50.], [0., 50.], [-10., 50.]]],
        ];
        final aligns:Array<glaze.TextAlign> = [Left, Center, Right];
        for (c in cases) {
            final wrapped:Bool = c[0];
            final alignWidth:Null<Float> = c[1];
            final edges:Array<Array<Float>> = c[2];
            final boundaries = wrapped ? [new WrapBoundary(0, 2)] : [];
            for (i in 0...3) {
                final bounds = LinePaint.linePaintBounds(origin, line.layout, lineHeight, aligns[i], alignWidth, boundaries);
                final left = edges[i][0];
                final right = edges[i][1];
                final expected = new glaze.Bounds(new Point(left, origin.y), new Size(right - left, wrapped ? 32 : 16));
                assertTrue(bounds.equals(expected), 'wrapped=$wrapped, align=${aligns[i]}, align_width=$alignWidth: expected $expected, got $bounds');
            }
        }
        final empty = makeShapedLine('', [], 0, []);
        for (align in aligns) {
            final bounds = LinePaint.linePaintBounds(origin, empty.layout, lineHeight, align, 100, []);
            assertTrue(bounds.equals(new glaze.Bounds(origin, new Size(0, lineHeight))));
        }
    }

    // Test window: GPUI's TestAppContext uses NoopTextSystem
    static function noopPainter(scaleFactor:Float):TextPainter {
        final textSystem = new TextSystem(new NoopTextSystem());
        final painter = new TextPainter(new Scene(), new HeadlessAtlas(), textSystem, scaleFactor, new glaze.Bounds(new Point(0, 0), new Size(1024, 1024)));
        // `window.with_element_opacity(Some(0.5), ...)`
        painter.elementOpacity = 0.5;
        return painter;
    }

    static function underlineTestLine(text:String, decorations:Array<DecorationRun>, zeroAdvance:Bool, textSystem:TextSystem):ShapedLine {
        final windowTs = new WindowTextSystem(textSystem);
        final line = windowTs.shapeLine(text, 16, [new glaze.TextRun(glaze.util.Utf8.byteLength(text), Font.of('.ZedMono'), Hsla.black())]);
        line.decorationRuns = decorations;
        final layout = line.layout;
        final runs = [for (run in layout.runs) run.clone()];
        final advance = zeroAdvance ? 0.0 : 8.0;
        var width = 0.0;
        for (run in runs) {
            for (i in 0...run.glyphs.length) {
                final g = run.glyphs[i];
                run.glyphs[i] = new ShapedGlyph(g.id, new Point(width, g.position.y), g.index, g.isEmoji);
                width += advance;
            }
        }
        line.layout = new LineLayout(layout.fontSize, width, layout.ascent, layout.descent, runs, layout.len);
        return line;
    }

    static function underlinesKey(scene:Scene):String {
        return [for (u in scene.underlines) '${u.boundsX},${u.boundsY},${u.boundsWidth},${u.boundsHeight},${u.contentMaskX},${u.contentMaskY},${u.contentMaskWidth},${u.contentMaskHeight},${u.colorH},${u.colorS},${u.colorL},${u.colorA},${u.thickness},${u.wavy},${u.order}'].join(' | ');
    }

    static function decoration(len:Int, ?underline:UnderlineStyle):DecorationRun {
        return new DecorationRun(len, Hsla.black(), null, underline, null);
    }

    function testUnderlineHandlerMatchesDefaultPaint() {
        for (scale in [1., 1.25, 1.5, 2., 3.]) {
            final painter = noopPainter(scale);
            final firstStyle = new UnderlineStyle(1, new Hsla(0, 1, 0.5, 1), true);
            final lastStyle = new UnderlineStyle(1, new Hsla(0.5, 1, 0.5, 1), false);
            final fallbackStyle = new UnderlineStyle(1, Hsla.black(), true);
            final line = underlineTestLine('aébcde', [
                decoration(1, firstStyle),
                decoration(2, firstStyle),
                decoration(1, null),
                decoration(1, new UnderlineStyle(1, null, true)),
                decoration(1, lastStyle),
                decoration(1, lastStyle),
            ], false, painter.textSystem);
            assertFloatEquals(48, line.width());
            for (originX in [-3.25, 0., 4.25]) {
                final cases:Array<Array<Dynamic>> = [
                    [glaze.TextAlign.Left, null, 0.],
                    [glaze.TextAlign.Center, null, 0.],
                    [glaze.TextAlign.Right, null, 0.],
                    [glaze.TextAlign.Left, 96., 0.],
                    [glaze.TextAlign.Center, 96., 24.],
                    [glaze.TextAlign.Right, 96., 48.],
                ];
                for (c in cases) {
                    final align:glaze.TextAlign = c[0];
                    final alignWidth:Null<Float> = c[1];
                    final offset:Float = c[2];
                    final origin = new Point(originX, 12.25);
                    final lineHeight = 20.0;
                    painter.scene.clear();
                    line.paint(origin, lineHeight, align, alignWidth, painter);
                    final original = underlinesKey(painter.scene);
                    painter.scene.clear();
                    line.layout.paint(origin, lineHeight, align, alignWidth, line.decorationRuns, painter);
                    assertEquals(original, underlinesKey(painter.scene));

                    painter.scene.clear();
                    final strokes:Array<String> = [];
                    line.paintWithUnderlineHandler(origin, lineHeight, align, alignWidth, painter, (start, end, o, width, style, p) -> {
                        strokes.push('$start..$end ${o.x},${o.y} ${(width:Float)} ${(style.thickness:Float)} ${style.color} ${style.wavy}');
                        p.paintUnderline(o, width, style);
                    });
                    final start = originX + offset;
                    final y = origin.y + TextSystem.underlineYOffset(lineHeight, line.ascent(), line.descent());
                    final expected = [
                        '0..3 $start,$y 16 1 ${firstStyle.color} true',
                        '4..5 ${start + 24},$y 8 1 ${fallbackStyle.color} true',
                        '5..7 ${start + 32},$y 16 1 ${lastStyle.color} false',
                    ];
                    assertEquals(expected.join(' / '), strokes.join(' / '), 'scale $scale origin $originX align $align');
                    assertEquals(original, underlinesKey(painter.scene));

                    painter.scene.clear();
                    final captured:Array<String> = [];
                    line.paintWithUnderlineHandler(origin, lineHeight, align, alignWidth, painter, (start, end, o, width, style, p) -> {
                        captured.push('$start..$end ${o.x},${o.y} ${(width:Float)} ${(style.thickness:Float)} ${style.color} ${style.wavy}');
                    });
                    assertEquals(strokes.join(' / '), captured.join(' / '));
                    assertEquals(0, painter.scene.underlines.length);
                }
            }
            for (text in ['', 'abc']) {
                final line = underlineTestLine(text, [], false, painter.textSystem);
                var calls = 0;
                line.paintWithUnderlineHandler(new Point(4, 10), 20, Left, null, painter, (_, _, _, _, _, _) -> calls++);
                assertEquals(0, calls);
            }
        }
    }

    function testUnderlineHandlerReportsZeroAdvanceGeometry() {
        for (scale in [1., 1.25, 1.5, 2., 3.]) {
            final painter = noopPainter(scale);
            final firstStyle = new UnderlineStyle(1, Hsla.black(), true);
            final lastStyle = new UnderlineStyle(1, Hsla.black(), false);
            final line = underlineTestLine('ab', [decoration(1, firstStyle), decoration(1, lastStyle)], true, painter.textSystem);
            final halfWidth = painter.textSystem.boundingBox(line.runs()[0].fontId, line.fontSize()).size.width / 2;
            final origin = new Point(40.25, 10.25);
            final lineHeight = 20.0;
            final y = origin.y + TextSystem.underlineYOffset(lineHeight, line.ascent(), line.descent());
            final cases:Array<Array<Dynamic>> = [[glaze.TextAlign.Left, 0.], [glaze.TextAlign.Center, 16.], [glaze.TextAlign.Right, 32.]];
            for (c in cases) {
                final align:glaze.TextAlign = c[0];
                final offset:Float = c[1];
                painter.scene.clear();
                line.paint(origin, lineHeight, align, 32, painter);
                final original = underlinesKey(painter.scene);
                painter.scene.clear();
                final strokes:Array<String> = [];
                line.paintWithUnderlineHandler(origin, lineHeight, align, 32, painter, (start, end, o, width, style, p) -> {
                    strokes.push('$start..$end ${o.x},${o.y} ${(width:Float)} ${style.wavy}');
                    p.paintUnderline(o, width, style);
                });
                final end = origin.x + offset;
                final startX = end - halfWidth;
                final width = end - startX;
                assertEquals('0..1 $startX,$y $width true / 1..2 $startX,$y $width false', strokes.join(' / '));
                assertEquals(original, underlinesKey(painter.scene));
            }
        }
    }

    function testUnderlineHandlerMatchesWrappedPaint() {
        for (scale in [1., 1.25, 1.5, 2., 3.]) {
            final painter = noopPainter(scale);
            final style = new UnderlineStyle(1, Hsla.black(), true);
            for (zeroAdvance in [false, true]) {
                final line = underlineTestLine('abcd', [new DecorationRun(4, Hsla.black(), null, style, null)], zeroAdvance, painter.textSystem);
                final halfWidth = painter.textSystem.boundingBox(line.runs()[0].fontId, line.fontSize()).size.width / 2;
                final origin = new Point(40.25, 10.25);
                final lineHeight = 20.0;
                final y = origin.y + TextSystem.underlineYOffset(lineHeight, line.ascent(), line.descent());
                final wrapped = new WrappedLine(new WrappedLineLayout(line.layout, [new WrapBoundary(0, 2)], 16), line.text, line.decorationRuns);
                painter.scene.clear();
                wrapped.paint(origin, lineHeight, Left, null, painter);
                final original = underlinesKey(painter.scene);
                painter.scene.clear();
                final strokes:Array<String> = [];
                LinePaint.paintLine(origin, wrapped.unwrappedLayout(), lineHeight, Left, 16, wrapped.decorationRuns, wrapped.wrapBoundaries(), painter, (start, end, o, width, s, p) -> {
                    strokes.push('$start..$end ${o.x},${o.y} ${(width:Float)}');
                    p.paintUnderline(o, width, s);
                });
                final startX = zeroAdvance ? origin.x - halfWidth : origin.x;
                final width = zeroAdvance ? origin.x - startX : 16.0;
                assertEquals('0..4 $startX,$y $width / 0..4 $startX,${y + lineHeight} $width', strokes.join(' / '), 'scale $scale zero advance $zeroAdvance');
                assertEquals(original, underlinesKey(painter.scene));
            }
        }
    }

    function testSplitAtInvariants() {
        final line = makeShapedLine('abcdef', [[0, 0], [1, 10], [2, 20], [3, 30], [4, 40], [5, 50]], 60, []);
        for (i in 0...7) {
            final parts = line.splitAt(i);
            final left = parts[0];
            final right = parts[1];
            assertFloatEquals(line.width(), left.width() + right.width(), 0, 'widths must sum at split=$i');
            assertEquals(line.len(), left.len() + right.len(), 'lengths must sum at split=$i');
            assertEquals('abcdef', left.text + right.text, 'text must concatenate at split=$i');
            assertFloatEquals(line.fontSize(), left.fontSize(), 0);
            assertFloatEquals(line.ascent(), right.ascent(), 0);
            assertFloatEquals(line.descent(), right.descent(), 0);
        }
        // Edge: split at 0 produces no left runs, full content on right
        var parts = line.splitAt(0);
        assertEquals(0, parts[0].runs().length);
        assertEquals(6, parts[1].runs()[0].glyphs.length);
        // Edge: split at end produces full content on left, no right runs
        parts = line.splitAt(6);
        assertEquals(6, parts[0].runs()[0].glyphs.length);
        assertEquals(0, parts[1].runs().length);
    }

    function testSplitAtGlyphRebasing() {
        // Two font runs (a font fallback boundary at byte 3)
        final line = new ShapedLine(new LineLayout(16, 60, 12, 4, [
            new ShapedRun(0, [glyphAt(0, 0), glyphAt(10, 1), glyphAt(20, 2)]),
            new ShapedRun(1, [glyphAt(30, 3), glyphAt(40, 4), glyphAt(50, 5)]),
        ], 6), 'abcdef', []);

        // First split at byte 2: mid-run in run A
        final first = line.splitAt(2);
        assertEquals('ab', first[0].text);
        assertEquals(1, first[0].runs().length);
        assertEquals(0, (first[0].runs()[0].fontId:Int));

        // Remainder "cdef" should have two runs: tail of A (1 glyph) + all of B (3 glyphs)
        final remainder = first[1];
        assertEquals('cdef', remainder.text);
        assertEquals(2, remainder.runs().length);
        assertEquals(0, (remainder.runs()[0].fontId:Int));
        assertEquals(1, remainder.runs()[0].glyphs.length);
        assertEquals(0, remainder.runs()[0].glyphs[0].index);
        assertFloatEquals(0, remainder.runs()[0].glyphs[0].position.x);
        assertEquals(1, (remainder.runs()[1].fontId:Int));
        assertEquals(1, remainder.runs()[1].glyphs[0].index);
        assertFloatEquals(10, remainder.runs()[1].glyphs[0].position.x);

        // Second split at byte 2 within remainder: crosses the run boundary
        final second = remainder.splitAt(2);
        assertEquals('cd', second[0].text);
        assertEquals('ef', second[1].text);
        assertEquals(0, second[1].runs()[0].glyphs[0].index);
        assertFloatEquals(0, second[1].runs()[0].glyphs[0].position.x);

        // Widths must sum across all three pieces
        assertFloatEquals(line.width(), first[0].width() + second[0].width() + second[1].width());
    }

    function testSplitAtDecorations() {
        final red = new Hsla(0.0, 1.0, 0.5, 1.0);
        final green = new Hsla(0.3, 1.0, 0.5, 1.0);
        final blue = new Hsla(0.6, 1.0, 0.5, 1.0);
        final line = makeShapedLine('abcdef', [[0, 0], [1, 10], [2, 20], [3, 30], [4, 40], [5, 50]], 60, [
            new DecorationRun(2, red),
            new DecorationRun(3, green),
            new DecorationRun(1, blue),
        ]);
        final parts = line.splitAt(3);
        final left = parts[0];
        final right = parts[1];
        assertEquals(2, left.decorationRuns.length);
        assertEquals(2, left.decorationRuns[0].len);
        assertTrue(left.decorationRuns[0].color.equals(red));
        assertEquals(1, left.decorationRuns[1].len);
        assertTrue(left.decorationRuns[1].color.equals(green));
        assertEquals(2, right.decorationRuns.length);
        assertEquals(2, right.decorationRuns[0].len);
        assertTrue(right.decorationRuns[0].color.equals(green));
        assertEquals(1, right.decorationRuns[1].len);
        assertTrue(right.decorationRuns[1].color.equals(blue));
    }

    function testCursorPreservesShapingMetadataAcrossRuns() {
        final line = new ShapedLine(new LineLayout(16, 50, 12, 4, [
            new ShapedRun(3, [
                new ShapedGlyph(11, new Point(0, 1), 0, true),
                new ShapedGlyph(12, new Point(17, 1), 1, false),
                new ShapedGlyph(13, new Point(19, -1), 1, false),
            ]),
            new ShapedRun(8, [
                new ShapedGlyph(21, new Point(25, 1), 5, true),
                new ShapedGlyph(22, new Point(41, 1), 7, false),
            ]),
        ], 10), 'a😀bcdef', []);
        final cursor = line.cursor();
        final first = cursor.takeUntil(5);
        assertEquals('a😀', first.text);
        assertEquals(3, (first.runs()[0].fontId:Int));
        assertEquals(11, (first.runs()[0].glyphs[0].id:Int));
        assertTrue(first.runs()[0].glyphs[0].isEmoji);
        assertEquals(1, first.runs()[0].glyphs[1].index);
        assertTrue(first.runs()[0].glyphs[1].position.equals(new Point(17, 1)));
        assertEquals(3, first.runs()[0].glyphs.length);
        assertEquals(1, first.runs()[0].glyphs[2].index);
        assertTrue(first.runs()[0].glyphs[2].position.equals(new Point(19, -1)));
        assertFloatEquals(25, cursor.xOffset());

        final second = cursor.takeUntil(7);
        assertEquals('bc', second.text);
        assertEquals(8, (second.runs()[0].fontId:Int));
        assertEquals(21, (second.runs()[0].glyphs[0].id:Int));
        assertEquals(0, second.runs()[0].glyphs[0].index);
        assertTrue(second.runs()[0].glyphs[0].position.equals(new Point(0, 1)));
        assertFloatEquals(41, cursor.xOffset());

        final finalPart = cursor.takeUntil(10);
        assertEquals('def', finalPart.text);
        assertEquals(8, (finalPart.runs()[0].fontId:Int));
        assertEquals(22, (finalPart.runs()[0].glyphs[0].id:Int));
        assertEquals(0, finalPart.runs()[0].glyphs[0].index);
        assertTrue(finalPart.runs()[0].glyphs[0].position.equals(new Point(0, 1)));
    }

    static function sameLine(a:ShapedLine, b:ShapedLine):String {
        if (a.text != b.text) return 'text ${a.text} != ${b.text}';
        if (a.len() != b.len()) return 'len';
        if (a.width() != b.width()) return 'width ${a.width()} != ${b.width()}';
        if (a.runs().length != b.runs().length) return 'run count';
        for (r in 0...a.runs().length) {
            final ra = a.runs()[r];
            final rb = b.runs()[r];
            if ((ra.fontId:Int) != (rb.fontId:Int)) return 'font id';
            if (ra.glyphs.length != rb.glyphs.length) return 'glyph count';
            for (g in 0...ra.glyphs.length) {
                final ga = ra.glyphs[g];
                final gb = rb.glyphs[g];
                if ((ga.id:Int) != (gb.id:Int) || ga.index != gb.index || !ga.position.equals(gb.position)) return 'glyph $g';
            }
        }
        return null;
    }

    function testCursorPreservesExistingVisualOrderSplitting() {
        final line = makeShapedLine('abc', [[0, 0], [2, 10], [1, 20]], 30, []);
        final cursor = line.cursor();
        var remainder = line.clone();
        var previousBoundary = 0;
        for (boundary in [0, 1, 2, 3]) {
            final parts = remainder.splitAt(boundary - previousBoundary);
            final actual = cursor.takeUntil(boundary);
            assertNull(sameLine(parts[0], actual));
            assertFloatEquals(line.layout.xForIndex(boundary), cursor.xOffset());
            remainder = parts[1];
            previousBoundary = boundary;
        }
    }

    function testCursorPartitionsOneDecorationAcrossThreeChunks() {
        final line = makeShapedLine('abcdef', [[0, 0], [1, 10], [2, 20], [3, 30], [4, 40], [5, 50]], 60, [new DecorationRun(6, new Hsla(0.2, 0.4, 0.6, 1.0))]);
        final cursor = line.cursor();
        assertEquals(2, cursor.takeUntil(2).decorationRuns[0].len);
        assertEquals(2, cursor.takeUntil(4).decorationRuns[0].len);
        assertEquals(2, cursor.takeUntil(6).decorationRuns[0].len);
    }

    function testCursorMatchesSuccessiveSplitsAtOrderedBoundaries() {
        final decorations = [for (len in [2, 0, 3, 1]) new DecorationRun(len, new Hsla(len / 10, 0.5, 0.5, 1.0), Hsla.black())];
        final line = makeShapedLine('abcdef', [[0, 5], [0, 5], [2, 15], [4, 25], [5, 35]], 45, decorations);
        for (first in 0...line.len() + 1) {
            for (second in first...line.len() + 1) {
                final cursor = line.cursor();
                var remainder = line.clone();
                var previousBoundary = 0;
                var totalWidth = 0.0;
                var text = '';
                for (boundary in [first, second, line.len(), line.len()]) {
                    final parts = remainder.splitAt(boundary - previousBoundary);
                    final expected = parts[0];
                    final actual = cursor.takeUntil(boundary);
                    final diff = sameLine(expected, actual);
                    assertNull(diff, 'first=$first second=$second boundary=$boundary');
                    assertEquals(expected.decorationRuns.length, actual.decorationRuns.length);
                    if (expected.decorationRuns.length == actual.decorationRuns.length) {
                        for (d in 0...expected.decorationRuns.length) {
                            assertEquals(expected.decorationRuns[d].len, actual.decorationRuns[d].len);
                            assertTrue(expected.decorationRuns[d].color.equals(actual.decorationRuns[d].color));
                        }
                    }
                    totalWidth += actual.width();
                    text += actual.text;
                    remainder = parts[1];
                    previousBoundary = boundary;
                }
                assertFloatEquals(line.width(), totalWidth);
                assertEquals(line.text, text);
            }
        }
    }

    function testCursorEmptyChunksAndRepeatedBoundaries() {
        final line = makeShapedLine('ab', [[0, 5], [1, 15]], 20, []);
        final cursor = line.cursor();
        assertEquals('', cursor.takeUntil(0).text);
        assertEquals('', cursor.takeUntil(0).text);
        assertEquals('a', cursor.takeUntil(1).text);
        assertEquals('b', cursor.takeUntil(2).text);
        assertEquals('', cursor.takeUntil(2).text);
        final empty = makeShapedLine('', [], 0, []);
        final piece = empty.cursor().takeUntil(0);
        assertEquals('', piece.text);
        assertEquals(0, piece.runs().length);
        assertFloatEquals(0, piece.width());
    }

    function testCursorRejectsInvalidBoundaries() {
        final line = makeShapedLine('é', [[0, 0]], 10, []);
        assertRaises(() -> line.cursor().takeUntil(1));
        final cursor = line.cursor();
        cursor.takeUntil(2);
        assertRaises(() -> cursor.takeUntil(0));
        assertRaises(() -> line.cursor().takeUntil(3));
    }

/// Painting

    /**
     * Glyph sprites follow `Window::paint_glyph`: the x origin (scaled) is
     * rounded to a quarter pixel, its fraction picks the subpixel variant
     * and the integer part positions the sprite with the raster bounds.
     */
    function testPaintGlyphQuantizesSubpixelVariants() {
        final ts = TextFixtures.textSystem();
        final atlas = new HeadlessAtlas();
        final scene = new Scene();
        final painter = new TextPainter(scene, atlas, ts, 2.0, new glaze.Bounds(new Point(0, 0), new Size(512, 512)));
        final fontId = ts.resolveFont(Font.of('Inter'));
        final glyphId:glaze.GlyphId = ts.platformTextSystem.glyphForChar(fontId, 'a'.code);
        // x origins (logical) and their expected (integer x, variant) at scale 2
        final cases:Array<Array<Float>> = [[10.0, 20, 0], [10.06, 20, 0], [10.07, 20, 1], [10.125, 20, 1], [10.2, 20, 2], [10.3, 20, 2], [10.32, 20, 3], [10.45, 21, 0], [-0.3, 0, 0]];
        for (c in cases) {
            scene.clear();
            painter.paintGlyph(new Point(c[0], 30), fontId, glyphId, 16, Hsla.black());
            assertEquals(1, scene.monochromeSprites.length);
            final sprite = scene.monochromeSprites[0];
            final variant = Std.int(c[2]);
            final params = new glaze.RenderGlyphParams(fontId, glyphId, 16, variant, 0, 2.0);
            final raster = ts.rasterBounds(params);
            assertFloatEquals(c[1] + raster.origin.x, sprite.boundsX, 0, 'x of origin ${c[0]}');
            assertFloatEquals(60 + raster.origin.y, sprite.boundsY, 0, 'y of origin ${c[0]}');
            assertFloatEquals(raster.size.width, sprite.boundsWidth, 0);
            assertFloatEquals(raster.size.height, sprite.boundsHeight, 0);
            assertTrue(atlas.contains(Glyph(params)), 'variant $variant of origin ${c[0]} rendered');
        }
    }

    function testShapedLinePaintEmitsSpritesAndDecorations() {
        final ts = TextFixtures.textSystem();
        final windowTs = new WindowTextSystem(ts);
        final atlas = new glaze.platform.CeramicAtlas(256, false, false);
        final scene = new Scene();
        final painter = new TextPainter(scene, atlas, ts, 2.0, new glaze.Bounds(new Point(0, 0), new Size(512, 512)));
        final underline = new UnderlineStyle(1, null, false);
        final strike = new glaze.StrikethroughStyle(1, Hsla.red());
        final runs = [
            new glaze.TextRun(6, Font.of('Inter'), Hsla.black(), null, underline),
            new glaze.TextRun(5, Font.of('Inter'), Hsla.blue(), Hsla.yellow(), null, strike),
        ];
        final line = windowTs.shapeLine('Hello world', 16, runs);
        line.paintBackground(new Point(10, 20), 24, Left, null, painter);
        line.paint(new Point(10, 20), 24, Left, null, painter);
        // 10 visible glyphs (the space has no outline)
        assertEquals(10, scene.monochromeSprites.length);
        assertEquals(2, scene.underlines.length);
        assertEquals(1, scene.quads.length);
        // Glyph colors follow the runs
        assertFloatEquals(0, scene.monochromeSprites[0].colorL);
        assertFloatEquals(Hsla.blue().h, scene.monochromeSprites[9].colorH);
        // Underline of "Hello " at the underline offset, in device pixels
        final u = scene.underlines[0];
        final y:Float = 20.0 + (TextSystem.underlineYOffset(24, line.ascent(), line.descent()):Float);
        assertFloatEquals(TextPainter.roundToDevicePixel(10, 2), u.boundsX, 0);
        assertFloatEquals(TextPainter.roundToDevicePixel(y, 2), u.boundsY, 0);
        assertFloatEquals(TextPainter.roundStrokeToDevicePixel(line.layout.xForIndex(6), 2), u.boundsWidth, 0);
        // Atlas pages hold the coverage of every painted glyph
        for (sprite in scene.monochromeSprites) {
            final data = atlas.pageData(sprite.textureIndex);
            var sum = 0;
            for (row in 0...Std.int(sprite.tileHeight))
                for (col in 0...Std.int(sprite.tileWidth))
                    sum += data.get(Std.int((sprite.tileY + row) * 256 + sprite.tileX + col));
            assertTrue(sum > 0, 'tile of a painted glyph is empty');
        }
        atlas.destroy();
    }


/// Cache generations (port: a third generation, see `LineLayoutCache`)

    function testCacheKeepsLinesUnusedForOneFrame() {
        final platform = new CountingTextSystem();
        final cache = new LineLayoutCache(platform);
        final runs = [new glaze.FontRun(5, 0)];
        final first = cache.layoutLine('hello', 16, runs, null);
        final wrapped = cache.layoutWrappedLine('hello', 16, runs, 40.0);
        assertEquals(1, platform.shaped);
        cache.finishFrame();
        // Unused for one frame (a filtered list hides the row)
        cache.finishFrame();
        // Back: the same layouts, not shaped again (GPUI shapes it again)
        assertTrue(cache.layoutLine('hello', 16, runs, null) == first);
        assertTrue(cache.layoutWrappedLine('hello', 16, runs, 40.0) == wrapped);
        assertEquals(1, platform.shaped);
        // Moved back to the current frame: kept by the next one
        cache.finishFrame();
        assertTrue(cache.layoutLine('hello', 16, runs, null) == first);
        assertEquals(1, platform.shaped);
        // Unused for two frames: dropped
        cache.finishFrame();
        cache.finishFrame();
        cache.finishFrame();
        assertTrue(cache.layoutLine('hello', 16, runs, null) != first);
        assertEquals(2, platform.shaped);
    }

    function testCacheByHashKeepsLinesUnusedForOneFrame() {
        final platform = new CountingTextSystem();
        final cache = new LineLayoutCache(platform);
        final runs = [new glaze.FontRun(5, 0)];
        final first = cache.layoutLineByHash(1234, 5, 16, runs, null, () -> 'hello');
        cache.finishFrame();
        cache.finishFrame();
        assertTrue(cache.tryLayoutLineByHash(1234, 5, 16, runs, null) == first);
        assertTrue(cache.layoutLineByHash(1234, 5, 16, runs, null, () -> 'hello') == first);
        assertEquals(1, platform.shaped);
        cache.finishFrame();
        cache.finishFrame();
        cache.finishFrame();
        assertTrue(cache.tryLayoutLineByHash(1234, 5, 16, runs, null) == null);
    }

}

/** `NoopTextSystem` counting its line shapings */
private class CountingTextSystem extends NoopTextSystem {

    public var shaped:Int = 0;

    override public function layoutLine(text:String, fontSize:glaze.Pixels, runs:Array<glaze.FontRun>):LineLayout {
        shaped++;
        return super.layoutLine(text, fontSize, runs);
    }

}

// Ported from gpui-kit 0.8.1: crates/component/src/sizing.rs (tests), crates/component/src/icon.rs (tests),
// crates/component/src/label.rs (tests), crates/component/src/index_path.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.TestDispatcher;
import glaze.Svg.Transformation;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.label.Label;
import glaze.kit.theme.Theme;
import haxe.io.Bytes;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.kit.Size.SizeTools;

/**
 * The `#[cfg(test)]` tests of gpui-component's sizing, icon and label modules.
 */
class ComponentFoundationsTest extends TestCase {

    var app:App;

    override function setup() {
        app = new App(new TestDispatcher());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        ceramic.App.app.flushImmediate();
    }

    function sizeEq(expected:Size, actual:Size, ?pos:haxe.PosInfos):Void {
        assertTrue(expected.equals(actual), 'expected $expected, got $actual', pos);
    }

    function testSizeMaxMin() {
        sizeEq(Small, Small.min(XSmall));
        sizeEq(Small, XSmall.min(Small));
        sizeEq(Medium, Small.min(Medium));
        sizeEq(Large, Medium.min(Large));
        sizeEq(Large, Large.min(Small));
        sizeEq(Size(20.), Size(10.).min(Size(20.)));

        sizeEq(XSmall, Small.max(XSmall));
        sizeEq(XSmall, XSmall.max(Small));
        sizeEq(Small, Small.max(Medium));
        sizeEq(Medium, Medium.max(Large));
        sizeEq(Small, Large.max(Small));
        sizeEq(Size(10.), Size(10.).max(Size(20.)));
    }

    function testSizeAsStr() {
        assertEquals('xs', XSmall.asStr());
        assertEquals('sm', Small.asStr());
        assertEquals('md', Medium.asStr());
        assertEquals('lg', Large.asStr());
        assertEquals('custom', Size(15.).asStr());
    }

    function testTableRowHeight() {
        assertEquals(26., XSmall.tableRowHeight());
        assertEquals(30., Small.tableRowHeight());
        assertEquals(32., Medium.tableRowHeight());
        assertEquals(40., Large.tableRowHeight());
        assertEquals(48., Size(48.).tableRowHeight());
    }

    function testSizeFromStr() {
        sizeEq(XSmall, SizeTools.fromStr('xs'));
        sizeEq(XSmall, SizeTools.fromStr('xsmall'));
        sizeEq(Small, SizeTools.fromStr('sm'));
        sizeEq(Small, SizeTools.fromStr('small'));
        sizeEq(Medium, SizeTools.fromStr('md'));
        sizeEq(Medium, SizeTools.fromStr('medium'));
        sizeEq(Large, SizeTools.fromStr('lg'));
        sizeEq(Large, SizeTools.fromStr('large'));
        sizeEq(Medium, SizeTools.fromStr('unknown'));
        // Case insensitive
        sizeEq(XSmall, SizeTools.fromStr('XS'));
        sizeEq(Small, SizeTools.fromStr('SMALL'));
        sizeEq(Medium, SizeTools.fromStr('Md'));
    }

    static final SVG = Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 19V5"/><path d="m5 12 7-7 7 7"/></svg>');

    function testIconBuilderPreservesOwnedDataAndTransformOnClone() {
        final transformation = Transformation.scaled(size(0.5, 0.5)).withRotation(radians(Math.PI / 2));
        final icon = Icon.component().data(SVG).large().textColor(red()).transform(transformation);
        final cloned = icon.clone();
        switch [icon.source, cloned.source] {
            case [Data(original), Data(copy)]:
                assertTrue(original == copy, 'cloning shares the data');
            case _:
                fail('cloning must preserve the data source');
        }
        assertTrue(cloned.transformation == transformation);
        assertTrue(cloned.size.equals(icon.size));
        assertTrue(cloned.textColorValue.equals(icon.textColorValue));

        final svg = cloned.intoSvg(12., blue());
        assertTrue(svg.style().text.color.equals(red()));
        assertTrue(Type.enumEq(svg.style().sizeWidth, glaze.Length.Definite(glaze.DefiniteLength.Absolute(glaze.AbsoluteLength.Rems(1.5)))));

        final rotated = icon.rotate(radians(Math.PI)).clone();
        assertEquals(Math.PI, (rotated.transformation.rotate : Float));
    }

    function testIconSourceBuildersReplacePreviousSource() {
        var icon = Icon.component(IconName.Search).data(SVG);
        assertTrue(icon.source.match(Data(_)));
        icon = icon.path('icons/replacement.svg');
        assertTrue(icon.source.match(Path('icons/replacement.svg')));
        icon = icon.data(SVG).data(Bytes.ofString('replacement'));
        switch icon.source {
            case Data(bytes): assertEquals('replacement', bytes.toString());
            case _: fail('data expected');
        }
        icon = icon.path('');
        assertTrue(icon.source.match(Path('')));
    }

    function testIconResolverReplacesThePathToDraw() {
        function drawnPath(icon:Icon):String {
            return switch icon.resolved(app).source {
                case Path(path): path;
                case Data(_): throw 'resolving must keep the source type';
            }
        }
        final search = IconName.Search.path();
        assertEquals(search, drawnPath(Icon.component(IconName.Search)));

        final asked:Array<String> = [];
        Icon.setIconResolver(app, (path, _) -> {
            asked.push(path);
            return path == search ? 'icons/alt/search.svg' : null;
        });
        assertEquals('icons/alt/search.svg', drawnPath(Icon.component(IconName.Search)));
        assertEquals(IconName.Check.path(), drawnPath(Icon.component(IconName.Check)));
        assertEquals('', drawnPath(Icon.empty()));
        assertTrue(Icon.component().data(SVG).resolved(app).source.match(Data(_)));
        assertEquals([search, IconName.Check.path()].join(','), asked.join(','));
    }

    function testIconNameIsGeneratedFromTheDefaultIcons() {
        assertEquals(106, IconName.ALL.length);
        assertEquals('icons/a-large-small.svg', IconName.ALL[0].path());
        assertEquals('icons/chevron-down.svg', IconName.ChevronDown.path());
        assertEquals('icons/star-fill.svg', IconName.StarFill.path());
    }

    function ranges(label:Label, length:Int):String {
        return [for (r in label.highlightRanges(length)) '${r[0]}..${r[1]}'].join(' ');
    }

    static function len(s:String):Int {
        return Bytes.ofString(s).length;
    }

    function testMaskedSecondaryTextAndHighlightsRender() {
        app.update(cx -> Theme.init(cx));
        final label = Label.component('é🙂').secondary('世界').highlights('🙂 世').masked(true);
        assertNull(label.measureHighlights(len('é🙂 世界'), app));
    }

    function testHighlightRanges() {
        // No highlights
        assertEquals('', ranges(Label.component('Hello World'), len('Hello World')));
        // Secondary text ranges only
        assertEquals('0..5 5..11', ranges(Label.component('Hello').secondary('World'), len('Hello World')));
        // Single match with case insensitive
        assertEquals('6..11', ranges(Label.component('Hello World').highlights('WORLD'), len('Hello World')));
        // Multiple matches
        assertEquals('0..5 6..11 12..17', ranges(Label.component('Hello Hello Hello').highlights('Hello'), len('Hello Hello Hello')));
        // No match and empty search
        assertEquals('', ranges(Label.component('Hello World').highlights('xyz'), len('Hello World')));
        assertEquals('', ranges(Label.component('Hello World').highlights(''), len('Hello World')));
        // Secondary + highlights in main text
        assertEquals('0..5 5..11 2..5', ranges(Label.component('Hello').secondary('World').highlights('llo'), len('Hello World')));
        // Highlight in secondary text
        assertEquals('0..5 5..11 6..11', ranges(Label.component('Hello').secondary('World').highlights('World'), len('Hello World')));
        // Cross-boundary highlight
        assertEquals('0..5 5..11 4..7', ranges(Label.component('Hello').secondary('World').highlights('o W'), len('Hello World')));
        // Overlapping matches
        final overlapping = Label.component('aaaa').highlights('aa').highlightRanges(4);
        assertTrue(overlapping.length >= 2);
        assertEquals('0,2', overlapping[0].join(','));
        assertEquals('1,3', overlapping[1].join(','));
        // Unicode text
        final text = '你好世界，Hello World';
        final start = len('你好');
        assertEquals('$start..${start + len('世界')}', ranges(Label.component(text).highlights('世界'), len(text)));
    }

    function testHighlightRangesPrefix() {
        assertEquals('0..2', ranges(Label.component('aaaa').highlights(Prefix('aa')), 4));
        assertEquals(2, Label.component('Hello Hello').highlights(Full('Hello')).highlightRanges(11).length);
        assertEquals('0..5', ranges(Label.component('Hello Hello').highlights(Prefix('Hello')), 11));
        assertEquals('0..5', ranges(Label.component('Hello hello HELLO').highlights(Prefix('hello')), 17));
        assertEquals('', ranges(Label.component('Hello World').highlights(Prefix('xyz')), 11));
        assertEquals('', ranges(Label.component('Hello World').highlights(Prefix('')), 11));
        assertEquals('0..5 5..17 0..5', ranges(Label.component('Hello').secondary('Hello World').highlights(Prefix('Hello')), len('Hello Hello World')));
        assertEquals('0..3 3..15 0..3', ranges(Label.component('abc').secondary('def abc def').highlights(Prefix('abc')), len('abc def abc def')));
        assertEquals('0..6', ranges(Label.component('你好世界你好').highlights(Prefix('你好')), len('你好世界你好')));
        assertEquals('0..4', ranges(Label.component('abababab').highlights(Prefix('abab')), 8));
        assertEquals('', ranges(Label.component('xyz Hello abc Hello').highlights(Prefix('Hello')), len('xyz Hello abc Hello')));
        assertTrue(Prefix('test').match(Prefix(_)));
        assertFalse(Full('test').match(Prefix(_)));
    }

    function testLegacyIndexPathExportIsTheBaseType() {
        final legacy:glaze.kit.base.IndexPath = new glaze.kit.base.IndexPath(2).withSection(1).withColumn(3);
        assertEquals(1, legacy.section);
    }

}

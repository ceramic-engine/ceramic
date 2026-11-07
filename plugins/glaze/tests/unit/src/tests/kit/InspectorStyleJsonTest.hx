// Ported from gpui-kit 0.8.1: crates/component/src/inspector.rs (style_to_rust, the serde JSON
// of StyleRefinement) and gpui-pre 0.3.10's refineable derive (is_superset_of, subtract)
// Original code Copyright 2024-2026 Longbridge, and Copyright 2022-2025 Zed Industries, Inc.,
// licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

#if gpui_inspector

import gpui.FontWeight;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.component.inspector.Inspector;
import gpui.component.inspector.InspectorStyleMethods;
import gpui.component.inspector.SerdeJson.SerdeError;
import gpui.component.inspector.StyleJson;
import testing.TestCase;

import gpui.Prelude.*;

using gpui.StyleRefinementOps;

/**
 * The data side of the inspector against the outputs of the real code
 * (`test/unit/data/inspector-reference.json`, written by the reference's
 * `examples/inspector_reflection.rs` with the feature `inspector`):
 *
 * - the serde JSON of the style each of the 3137 reflected methods sets;
 * - `style_to_rust` (code, convertible style, unconvertible rest) of styles
 *   covering every field;
 * - `serde_json::from_str::<StyleRefinement>` on valid and invalid inputs
 *   (the style, or the exact error message with its line and column);
 * - `is_superset_of` and `subtract` of every pair of these styles.
 */
class InspectorStyleJsonTest extends TestCase {

    static var cached:Dynamic = null;

    static function reference():Dynamic {
        if (cached == null) cached = haxe.Json.parse(InspectorReference.content());
        return cached;
    }

    function testEveryReflectedMethodSerializesLikeRust() {
        final table:Array<Array<String>> = reference().table;
        final methods = InspectorStyleMethods.get().table;
        assertEquals(table.length, methods.length);
        var mismatches = 0;
        for (i in 0...table.length) {
            assertEquals(table[i][0], methods[i].method.name);
            final json = StyleJson.toJson(methods[i].style);
            if (json != table[i][1]) {
                mismatches++;
                if (mismatches <= 5) assertEquals(table[i][1], json, table[i][0]);
            }
        }
        assertEquals(0, mismatches);
    }

    /**
     * The styles of the reference's cases, built with the same builder
     * calls (their JSON loses precision: `#0000001a` is not `hsla(0, 0, 0,
     * 0.1)`, `33%` is not `relative(1. / 3.)`).
     */
    static function cases():Map<String, StyleRefinement> {
        final d = () -> new StyleBuilder();
        final scroll = d().overflowYHidden().style();
        scroll.overflowX = Scroll;
        return [
            'empty' => d().style(),
            'p_1_mx_2' => d().p1().mx2().style(),
            'flex_col_gap' => d().flex().flexCol().gap2().itemsCenter().style(),
            'size_full' => d().sizeFull().style(),
            'w_full_h_8' => d().wFull().h8().style(),
            'border_rounded' => d().border1().roundedMd().borderDashed().style(),
            'bg' => d().bg(rgb(0x336699)).p2().style(),
            'text' => d().textSm().fontWeight(FontWeight.BOLD).textColor(hsla(0.5, 0.25, 0.75, 1.0)).fontFamily('Inter').italic().underline().style(),
            'shadow' => d().shadowMd().opacity(0.5).style(),
            'grid' => d().grid().gridCols(3).gridRows(2).colSpan(2).rowStart(1).style(),
            'positions' => d().absolute().top1().leftNeg2().inset0().style(),
            'overflow' => d().overflowHidden().cursorPointer().invisible().style(),
            'misc' => d().aspectRatio(1.5).flex1().flexShrink0().flexBasis(relative(0.5)).textEllipsis().lineClamp(2).whitespaceNowrap().style(),
            'h_flex_ext' => d().flex().flexRow().itemsCenter().style(),
            'v_flex_ext' => d().flex().flexCol().style(),
            'text_decoration' => d().lineThrough().textDecorationWavy().textDecoration1().textCenter().lineHeight(rems(1.5)).textSize(px(13.)).textBg(rgb(0xff0000)).style(),
            'min_max' => d().minW0().maxWFull().minH(px(10.)).maxH(rems(4.)).style(),
            'justify' => d().justifyBetween().contentCenter().selfStart().flexWrap().style(),
            'corners' => d().roundedTlLg().roundedBr(px(3.)).borderT2().borderColor(rgb(0x00ff00)).style(),
            'scroll' => scroll,
            'odd' => d().w(px(10.5)).h(relative(1. / 3.)).m(px(-0.25)).p(rems(0.3)).style()
        ];
    }

    function testStyleToRustMatchesRust() {
        final cases:Array<Dynamic> = reference().style_to_rust;
        final styles = InspectorStyleJsonTest.cases();
        for (c in cases) {
            final input = styles.get(Reflect.field(c, 'case'));
            assertEquals((c.input : String), StyleJson.toJson(input), Reflect.field(c, 'case'));
            final result = Inspector.styleToRust(input);
            assertEquals((c.code : String), result.code, Reflect.field(c, 'case'));
            assertEquals((c.style : String), StyleJson.toJson(result.style), Reflect.field(c, 'case'));
            assertEquals((c.unconvertible : String), StyleJson.toJson(input.subtract(result.style)), Reflect.field(c, 'case'));
        }
    }

    function testDeserializationMatchesSerdeJson() {
        final cases:Array<Dynamic> = reference().serde;
        for (c in cases) {
            var actual:String;
            try {
                actual = 'ok ' + StyleJson.toJson(StyleJson.fromJson(c.input));
            }
            catch (e:SerdeError) {
                actual = 'err ' + e.toString();
            }
            final expected = c.ok != null ? 'ok ' + c.ok : 'err ' + c.err;
            assertEquals(expected, actual, c.input);
        }
    }

    function testSupersetAndSubtractMatchRust() {
        final styles = cases();
        for (pair in (reference().pairs : Array<Dynamic>)) {
            final a = styles.get(pair.a);
            final b = styles.get(pair.b);
            assertEquals((pair.superset : Bool), a.isSupersetOf(b), pair.a + ' >= ' + pair.b);
            assertEquals((pair.subtract : String), StyleJson.toJson(a.subtract(b)), pair.a + ' - ' + pair.b);
        }
    }

    function testDisplays() {
        final display:Dynamic = reference().display;
        assertEquals((display.point : String), '(' + StyleJson.absoluteDisplay(Pixels(10)) + ', ' + StyleJson.absoluteDisplay(Pixels(20.5)) + ')');
        assertEquals((display.size : String), StyleJson.absoluteDisplay(Pixels(1 / 3)) + ' × ' + StyleJson.absoluteDisplay(Pixels(100)));
        assertEquals((display.point_neg : String), '(' + StyleJson.absoluteDisplay(Pixels(-0.0)) + ', ' + StyleJson.absoluteDisplay(Pixels(1e-7)) + ')');
        assertEquals((display.size_big : String), StyleJson.absoluteDisplay(Pixels(123456789)) + ' × ' + StyleJson.absoluteDisplay(Pixels(0.1)));
    }

}

#end

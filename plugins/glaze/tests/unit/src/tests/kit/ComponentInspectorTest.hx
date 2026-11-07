// Ported from gpui-kit 0.8.1: crates/component/src/inspector.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AbsoluteLength;
import glaze.DefiniteLength;
import glaze.Length;
import glaze.StyleRefinement;
import glaze.kit.inspector.Inspector;
import glaze.kit.inspector.InspectorStyleMethods;
import testing.TestCase;

/**
 * The test of gpui-component's `inspector.rs`, plus checks of the reflected
 * style method table the port builds from its `Styled` methods.
 */
class ComponentInspectorTest extends TestCase {

    function testRustToStyle() {
        final result = Inspector.rustToStyle(new StyleRefinement(), 'fn build() -> Div {\n    div()\n        .p_1()\n        // This is a comment\n        .mx_2()\n}\n');
        assertEquals(0, result.diagnostics.length);
        assertTrue(Type.enumEq(DefiniteLength.Absolute(AbsoluteLength.Rems(0.25)), result.style.paddingLeft));
        assertTrue(Type.enumEq(Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(0.5))), result.style.marginLeft));

        final bad = Inspector.rustToStyle(new StyleRefinement(), 'fn build() -> Div {\n    div()\n        .p_1()\n        // This is a comment\n        .unknown_method\n        .bad_method()\n}\n');
        assertEquals(2, bad.diagnostics.length);
        assertEquals('unknown method `unknown_method`', bad.diagnostics[0].message);
        assertEquals('4:9', bad.diagnostics[0].range.start.line + ':' + bad.diagnostics[0].range.start.character);
        assertEquals('4:23', bad.diagnostics[0].range.end.line + ':' + bad.diagnostics[0].range.end.character);
        assertEquals('unknown method `bad_method`', bad.diagnostics[1].message);
        assertEquals('5:9', bad.diagnostics[1].range.start.line + ':' + bad.diagnostics[1].range.start.character);
        assertEquals('5:19', bad.diagnostics[1].range.end.line + ':' + bad.diagnostics[1].range.end.character);
    }

    function testMissingDivIsReported() {
        final result = Inspector.rustToStyle(new StyleRefinement(), 'span()');
        assertEquals(1, result.diagnostics.length);
        assertEquals('expected `div()`', result.diagnostics[0].message);
    }

    function testStyleMethodTableFollowsTheRustReflection() {
        final methods = InspectorStyleMethods.get();
        // gpui-base's StyledExt methods first, then gpui's Styled ones, in declaration order
        assertEquals('h_flex,v_flex,debug_red,debug_blue,debug_yellow,debug_green,debug_pink,w_0,w_neg_0,w_0p5',
            [for (i in 0...10) methods.table[i].method.name].join(','));
        assertEquals(3137, methods.table.length);
        assertEquals('row_span_full', methods.table[methods.table.length - 1].method.name);
        for (name in ['p_1', 'mx_2', 'h_flex', 'v_flex', 'w_full', 'rounded_md', 'text_sm', 'flex_1', 'overflow_hidden', 'cursor_pointer', 'border_1', 'shadow_md']) {
            assertTrue(methods.map.exists(name), name);
        }
        assertEquals('Lays children out in a column, stretching them across the cross axis.', methods.map.get('v_flex').documentation.split('\n')[0]);
        assertEquals(null, methods.map.get('debug_red').documentation);
        // The style each method sets on a default refinement
        final p1 = methods.map.get('p_1').invoke(new StyleRefinement());
        assertTrue(Type.enumEq(DefiniteLength.Absolute(AbsoluteLength.Rems(0.25)), p1.paddingTop));
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/fold_map.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Range;
import glaze.kit.base.input.FoldMap;
import glaze.kit.base.input.FoldRange;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.input.FoldMap` (Rust `fold_map.rs`).
 */
@:access(glaze.kit.base.input.FoldMap)
class InputFoldMapTest extends TestCase {

    /**
     * The per-row tables the projection used to be stored as: display row to
     * wrap row, and wrap row to display row.
     */
    static function denseProjection(wrapRowCount:Int, hidden:Array<Range>):{visible:Array<Int>, displayRows:Array<Null<Int>>} {
        final visible:Array<Int> = [];
        final displayRows:Array<Null<Int>> = [for (_ in 0...wrapRowCount) null];
        for (wrapRow in 0...wrapRowCount) {
            var isHidden = false;
            for (range in hidden) {
                if (range.contains(wrapRow))
                    isHidden = true;
            }
            if (!isHidden) {
                displayRows[wrapRow] = visible.length;
                visible.push(wrapRow);
            }
        }
        return {visible: visible, displayRows: displayRows};
    }

    function testHiddenRunsMatchTheDenseProjection() {
        final wrapRowCount = 10;
        inline function r(a:Int, b:Int) return new Range(a, b);
        final cases:Array<Array<Range>> = [
            [],
            [r(0, 3)],
            [r(2, 5)],
            [r(7, 10)],
            [r(2, 4), r(4, 6)],
            [r(1, 5), r(3, 8)],
            [r(6, 9), r(1, 3)],
            [r(0, 2), r(3, 4), r(8, 20)],
            [r(0, 10)],
        ];
        for (hidden in cases) {
            final label = hidden.map(h -> h.toString()).join(',');
            final foldMap = new FoldMap();
            foldMap.folded.push(new FoldRange(0, 1));
            foldMap.setHiddenRows(wrapRowCount, hidden);
            final dense = denseProjection(wrapRowCount, hidden);
            final visible = dense.visible;

            assertEquals(visible.length, foldMap.displayRowCount(), label);
            for (wrapRow in 0...wrapRowCount + 2) {
                final displayRow = wrapRow < dense.displayRows.length ? dense.displayRows[wrapRow] : null;
                assertEquals(displayRow, foldMap.wrapRowToDisplayRow(wrapRow), '$label, wrap row $wrapRow');
                // visible.binary_search(&wrap_row): Ok(index) => index, Err(index) => index - 1
                var nearest = 0;
                final found = visible.indexOf(wrapRow);
                if (found >= 0) {
                    nearest = found;
                }
                else {
                    var index = 0;
                    while (index < visible.length && visible[index] < wrapRow)
                        index++;
                    nearest = index > 0 ? index - 1 : 0;
                }
                assertEquals(nearest, foldMap.nearestVisibleDisplayRow(wrapRow), '$label, wrap row $wrapRow');
            }
            for (displayRow in 0...wrapRowCount + 2) {
                final expected:Null<Int> = displayRow < visible.length ? visible[displayRow] : null;
                assertEquals(expected, foldMap.displayRowToWrapRow(displayRow), '$label, display row $displayRow');
            }
        }
    }

}

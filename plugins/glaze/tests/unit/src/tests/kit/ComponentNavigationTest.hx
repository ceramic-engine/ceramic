// Ported from gpui-kit 0.8.1: crates/component/src/pagination.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Range;
import glaze.kit.pagination.Pagination;
import testing.TestCase;

/**
 * The `#[cfg(test)]` tests of gpui-component's `pagination.rs`. The stepper
 * has no tests of its own (its integration test steps are in
 * `ComponentDisclosureTest`); its behaviour is checked by the golden
 * scripts.
 */
class ComponentNavigationTest extends TestCase {

    static function pages(hidden:Range, currentPage:Int):String {
        return @:privateAccess Pagination.ellipsisMenuPages(hidden, currentPage).toString();
    }

    function testEllipsisMenuPages() {
        // Short gaps list every hidden page.
        assertEquals('2..8', pages(new Range(2, 8), 1));
        assertEquals('2..8', pages(new Range(2, 8), 9));

        // Long gaps keep the pages next to the current page.
        assertEquals('4..104', pages(new Range(4, 10000), 1));
        assertEquals('9897..9997', pages(new Range(2, 9997), 10000));
        assertEquals('5003..5103', pages(new Range(5003, 10000), 5000));
        assertEquals('4898..4998', pages(new Range(2, 4998), 5000));
    }

}

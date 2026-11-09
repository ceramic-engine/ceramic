// Ported from vscode src/vs/editor/test/common/model/textModelTokens.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.common.core.OffsetRange;
import cityscape.common.model.TextModelTokens.RangePriorityQueueImpl;
import testing.TestCase;

class TextModelTokensTest extends TestCase {

    function strings(ranges:Array<OffsetRange>):Array<String> {
        return [for (r in ranges) r.toString()];
    }

    function testAddRange() {
        final ranges:Array<OffsetRange> = [];

        OffsetRange.addRange(new OffsetRange(0, 2), ranges);
        OffsetRange.addRange(new OffsetRange(10, 13), ranges);
        OffsetRange.addRange(new OffsetRange(20, 24), ranges);

        assertDeepEquals(['[0, 2)', '[10, 13)', '[20, 24)'], strings(ranges));

        OffsetRange.addRange(new OffsetRange(2, 10), ranges);

        assertDeepEquals(['[0, 13)', '[20, 24)'], strings(ranges));

        OffsetRange.addRange(new OffsetRange(14, 19), ranges);

        assertDeepEquals(['[0, 13)', '[14, 19)', '[20, 24)'], strings(ranges));

        OffsetRange.addRange(new OffsetRange(10, 22), ranges);

        assertDeepEquals(['[0, 24)'], strings(ranges));

        OffsetRange.addRange(new OffsetRange(-1, 29), ranges);

        assertDeepEquals(['[-1, 29)'], strings(ranges));

        OffsetRange.addRange(new OffsetRange(-10, -5), ranges);

        assertDeepEquals(['[-10, -5)', '[-1, 29)'], strings(ranges));
    }

    function testAddRangeAndResize() {
        final queue = new RangePriorityQueueImpl();

        queue.addRange(new OffsetRange(0, 20));
        queue.addRange(new OffsetRange(100, 120));
        queue.addRange(new OffsetRange(200, 220));

        // disjoint
        queue.addRangeAndResize(new OffsetRange(25, 27), 0);

        assertDeepEquals(['[0, 20)', '[98, 118)', '[198, 218)'], strings(queue.getRanges()));

        queue.addRangeAndResize(new OffsetRange(19, 20), 0);

        assertDeepEquals(['[0, 19)', '[97, 117)', '[197, 217)'], strings(queue.getRanges()));

        queue.addRangeAndResize(new OffsetRange(19, 97), 0);

        assertDeepEquals(['[0, 39)', '[119, 139)'], strings(queue.getRanges()));

        queue.addRangeAndResize(new OffsetRange(-1000, 1000), 0);

        assertDeepEquals([], strings(queue.getRanges()));
    }

}

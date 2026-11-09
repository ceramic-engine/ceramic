// New code for Cityscape (not a port): the check of the rendered line cache
// over the whole unit suite.
package tests.view;

import cityscape.view.CityscapeView;
import testing.TestCase;

/**
 * The view keeps a rendered line while no view event invalidated it (its
 * rendering input is not built again, like Monaco's `ViewLine`). The unit
 * suite runs with `CityscapeView.checkRenderCache` on (`Project.ready`):
 * every rendered line is checked against its input, and a line kept while
 * its input changed is counted. Registered last, this test reads the count
 * of the whole suite.
 */
class RenderCacheCheckTest extends TestCase {

    function testNoLineKeptWhileItsInputChanged() {
        assertTrue(CityscapeView.checkRenderCache);
        assertEquals(0, CityscapeView.renderCacheErrors);
    }

}

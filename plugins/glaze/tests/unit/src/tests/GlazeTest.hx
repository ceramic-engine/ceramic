package tests;

import testing.TestCase;

class GlazeTest extends TestCase {

    function testPluginIsAvailable() {
        assertEquals('0.0.1', glaze.Glaze.VERSION);
    }

}

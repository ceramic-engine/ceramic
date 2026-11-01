package tests;

import testing.TestCase;

class GpuiTest extends TestCase {

    function testPluginIsAvailable() {
        assertEquals('0.0.1', gpui.Gpui.VERSION);
    }

}

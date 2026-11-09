package tests;

import testing.TestCase;

/**
 * Checks the plugin setup: the project enables cityscape and glaze.
 */
class PluginSetupTest extends TestCase {

    function testPluginDefines() {
        #if plugin_cityscape
        assertTrue(true);
        #else
        fail('plugin_cityscape is not defined');
        #end
        #if plugin_glaze
        assertTrue(true);
        #else
        fail('plugin_glaze is not defined: cityscape needs glaze');
        #end
    }

}

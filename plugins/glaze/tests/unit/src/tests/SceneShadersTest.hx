package tests;

import gpui.platform.SceneRenderable;
import testing.TestCase;

/**
 * Tests for the choice between the default and the compact scene shaders
 * (`SceneRenderable.chooseShaders()`): the compact ones only when the GPU
 * limits are too low for the default ones, like WebGL in Firefox with
 * fingerprinting resistance (8 varying vectors) or
 * `webgl.min_capability_mode` (8 attributes, 8 varying vectors). The pixel
 * equality of both sets is checked by the golden harness.
 */
class SceneShadersTest extends TestCase {

    function testDefaultShadersWithUsualLimits():Void {
        // WebGL 2 minimums, Chromium, Firefox, desktop GL
        assertFalse(SceneRenderable.needsCompactShaders(16, 15));
        assertFalse(SceneRenderable.needsCompactShaders(16, 31));
        assertFalse(SceneRenderable.needsCompactShaders(16, 32));
        assertFalse(SceneRenderable.needsCompactShaders(32, 32));
    }

    function testThresholds():Void {
        // GpuiQuad reads 12 attributes and 10 varying rows
        assertFalse(SceneRenderable.needsCompactShaders(12, 10));
        assertTrue(SceneRenderable.needsCompactShaders(11, 10));
        assertTrue(SceneRenderable.needsCompactShaders(12, 9));
    }

    function testCompactShadersWithFirefoxLimits():Void {
        // resistFingerprinting
        assertTrue(SceneRenderable.needsCompactShaders(16, 8));
        // webgl.min_capability_mode
        assertTrue(SceneRenderable.needsCompactShaders(8, 8));
    }

    function testHeadlessBackendChoosesDefaultShaders():Void {
        #if !gpui_compact_shaders
        assertFalse(SceneRenderable.chooseShaders());
        assertFalse(SceneRenderable.useCompactShaders);
        #end
    }

}

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
        #if (!gpui_compact_shaders && !unity)
        assertFalse(SceneRenderable.chooseShaders());
        assertFalse(SceneRenderable.useCompactShaders);
        #end
    }

    function testUnityBackendChoosesCompactShaders():Void {
        // Unity meshes give position, color, uv and 7 custom attributes
        // (TEXCOORD1 to TEXCOORD7): GpuiQuad's 9 custom attributes do not
        // fit (Metal refused its pipeline state), the compact shaders do
        assertTrue(SceneRenderable.needsCompactShaders(10, 32));
        #if unity
        assertEquals(10, ceramic.App.app.backend.shaders.maxVertexAttributes());
        assertTrue(SceneRenderable.chooseShaders());
        assertTrue(SceneRenderable.useCompactShaders);
        #end
    }

}

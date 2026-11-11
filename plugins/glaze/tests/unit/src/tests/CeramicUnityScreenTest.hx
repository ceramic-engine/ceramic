package tests;

import testing.TestCase;

/**
 * The screen of Ceramic's Unity backend when it is sized from the window
 * settings (`CERAMIC_UNITY_SCREEN_SIZE=window`, the goldens and captures in
 * batch mode, where Unity has no window): the size the app asks for is
 * resolved once and kept, because once the app runs `ceramic.Screen` copies
 * the actual screen size into `settings.windowWidth` / `windowHeight` at
 * every resize (`syncWindowSize()`). Reading the settings again at each
 * update fed the screen size back to itself: every golden scenario on Unity
 * aborted with a 640x480 screen (2026-11-11). `setWindowSize()` is the way to
 * change that screen afterwards (`settings.windowSize()`).
 *
 * Unity only: the other backends have a real window.
 */
class CeramicUnityScreenTest extends TestCase {

    #if unity

    function testWindowSizedScreenIsResolvedOnceAndResizedThroughSetWindowSize() {

        final backendScreen = @:privateAccess ceramic.App.app.backend.screen;
        final coreScreen = ceramic.App.app.screen;
        final settings = ceramic.App.app.settings;
        final fromWindowWas = @:privateAccess backendScreen.screenSizeFromWindowSettings;
        final widthOverrideWas = @:privateAccess backendScreen.pixelWidthOverride;
        final heightOverrideWas = @:privateAccess backendScreen.pixelHeightOverride;
        final pixelWidthWas = @:privateAccess backendScreen.pixelWidth;
        final pixelHeightWas = @:privateAccess backendScreen.pixelHeight;
        final windowWidthWas = settings.windowWidth;
        final windowHeightWas = settings.windowHeight;
        final density = @:privateAccess backendScreen.computeDensity();

        // The core's sync of the settings with the actual screen, without a
        // resize request (what happens at every resize of ceramic.Screen)
        inline function syncSettings(width:Int, height:Int) {
            @:privateAccess coreScreen.syncingWindowSize = true;
            settings.windowWidth = width;
            settings.windowHeight = height;
            @:privateAccess coreScreen.syncingWindowSize = false;
        }

        function restore() {
            @:privateAccess backendScreen.screenSizeFromWindowSettings = fromWindowWas;
            @:privateAccess backendScreen.pixelWidthOverride = widthOverrideWas;
            @:privateAccess backendScreen.pixelHeightOverride = heightOverrideWas;
            @:privateAccess backendScreen.pixelWidth = pixelWidthWas;
            @:privateAccess backendScreen.pixelHeight = pixelHeightWas;
            syncSettings(windowWidthWas, windowHeightWas);
        }

        try {
            @:privateAccess backendScreen.screenSizeFromWindowSettings = true;
            @:privateAccess backendScreen.pixelWidthOverride = 0;
            @:privateAccess backendScreen.pixelHeightOverride = 0;

            // The requested size is resolved from the window settings
            syncSettings(300, 200);
            @:privateAccess backendScreen.readPixelSize();
            assertEquals(Math.round(300 * density), @:privateAccess backendScreen.pixelWidth);
            assertEquals(Math.round(200 * density), @:privateAccess backendScreen.pixelHeight);

            // The settings following the screen (or anything else) no longer
            // change the resolved size
            syncSettings(123, 45);
            @:privateAccess backendScreen.readPixelSize();
            assertEquals(Math.round(300 * density), @:privateAccess backendScreen.pixelWidth);
            assertEquals(Math.round(200 * density), @:privateAccess backendScreen.pixelHeight);

            // setWindowSize() resizes it (same size: nothing to do)
            assertFalse(backendScreen.setWindowSize(300, 200));
            assertTrue(backendScreen.setWindowSize(320, 240));
            @:privateAccess backendScreen.readPixelSize();
            assertEquals(Math.round(320 * density), @:privateAccess backendScreen.pixelWidth);
            assertEquals(Math.round(240 * density), @:privateAccess backendScreen.pixelHeight);
        }
        catch (e:haxe.Exception) {
            restore();
            throw e;
        }
        restore();

    }

    #end

}

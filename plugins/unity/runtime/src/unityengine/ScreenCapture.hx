package unityengine;

/**
 * Utility class for capturing screenshots of the game view.
 * Provides various methods to capture screen content to files or textures.
 * 
 * In Ceramic applications, this can be used for:
 * - Creating screenshots for debugging or sharing
 * - Capturing frames for video recording
 * - Generating thumbnails or previews
 * - Creating visual effects (e.g., pause menu backgrounds)
 * 
 * Note: Screenshots capture the rendered frame after all post-processing.
 * 
 * @see Texture2D
 * @see RenderTexture
 */
@:native('UnityEngine.ScreenCapture')
extern class ScreenCapture {

    /**
     * Captures a screenshot and saves it to a file.
     * 
     * @param filename Path to save the screenshot. Supports:
     *                - Relative paths (saved in persistent data)
     *                - Absolute paths (requires permissions)
     *                - Extensions: .png, .jpg, .exr, .tga
     * @param superSize Resolution multiplier (1-32):
     *                 - 1 = Native resolution
     *                 - 2 = 2x resolution (4x pixels)
     *                 - 4 = 4x resolution (16x pixels)
     * 
     * @example Capturing at 2x resolution:
     * ```haxe
     * ScreenCapture.CaptureScreenshot("screenshot.png", 2);
     * ```
     * 
     * Note: Executes at end of frame. File I/O may cause frame hitch.
     */
    static function CaptureScreenshot(filename:String, superSize:Int):Void;

    /**
     * Captures a screenshot directly to a Texture2D.
     * Useful for in-game use without file I/O.
     * 
     * @param superSize Resolution multiplier (1-32)
     * @return New Texture2D containing the screenshot
     * 
     * @example Creating a pause menu background:
     * ```haxe
     * var screenshot = ScreenCapture.CaptureScreenshotAsTexture(1);
     * pauseBackground.texture = screenshot;
     * ```
     * 
     * Important: Remember to destroy the texture when done
     * to avoid memory leaks.
     */
    static function CaptureScreenshotAsTexture(superSize:Int):Texture2D;

    /**
     * Captures a screenshot into an existing RenderTexture.
     * Most efficient method as it reuses existing GPU memory.
     * 
     * @param renderTexture Target RenderTexture (must be created)
     *                     Size determines capture resolution
     * 
     * @example Continuous capture for effects:
     * ```haxe
     * // In update loop
     * ScreenCapture.CaptureScreenshotIntoRenderTexture(myRT);
     * // Use myRT for blur, transitions, etc.
     * ```
     * 
     * Note: RenderTexture must have compatible format and be
     * currently allocated (not released).
     */
    static function CaptureScreenshotIntoRenderTexture(renderTexture:RenderTexture):Void;

}

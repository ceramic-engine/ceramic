package ceramic;

import ceramic.App;
import ceramic.Shortcuts.*;

/**
 * Runtime entry point of the `glaze` plugin.
 *
 * `pluginInit()` is called automatically by Ceramic's `PluginsMacro` (plugin name `Glaze`).
 */
@:access(ceramic.App)
class GlazePlugin {

    /**
     * Fonts loaded with the default assets and added to
     * `glaze.App.defaultTextSystem()` (define `glaze_no_default_fonts` to skip).
     * `.SystemUIFont` is Inter.
     */
    public static final DEFAULT_FONTS:Array<String> = [
        'glaze/fonts/Inter-Regular.ttf.bin',
        'glaze/fonts/JetBrainsMono-Regular.ttf.bin'
    ];

    @:keep static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init glaze plugin (version ${glaze.Glaze.VERSION})');

            // GPUI scene shaders are loaded with the default assets,
            // so they are ready before the first scene is created
            App.app.onceDefaultAssetsLoad(null, function(assets) {
                // The compact variants of the quad, shadow and path shaders
                // when the GPU limits are too low for the default ones
                if (glaze.platform.SceneRenderable.chooseShaders()) {
                    final backendShaders = App.app.backend.shaders;
                    log.info('Glaze uses its compact shaders (max vertex attributes: ${backendShaders.maxVertexAttributes()}, max varying vectors: ${backendShaders.maxVaryingVectors()})');
                    assets.add(shaders.GlazeQuadCompact);
                    assets.add(shaders.GlazeShadowCompact);
                    assets.add(shaders.GlazeUnderline);
                    assets.add(shaders.GlazeMonoSprite);
                    assets.add(shaders.GlazePolySprite);
                    assets.add(shaders.GlazePathSpriteCompact);
                }
                else {
                    assets.add(shaders.GlazeQuad);
                    assets.add(shaders.GlazeShadow);
                    assets.add(shaders.GlazeUnderline);
                    assets.add(shaders.GlazeMonoSprite);
                    assets.add(shaders.GlazePolySprite);
                    assets.add(shaders.GlazePathSprite);
                }

                #if glaze_bundled_emoji
                // Bundled emoji font (Noto Color Emoji, define
                // glaze_bundled_emoji), added after the bundled text fonts,
                // before the app is ready. Browsers load the whole file as a
                // binary asset; other targets read it piece by piece from
                // the assets folder.
                var pendingFonts = 0;
                var emojiBytes:Null<haxe.io.Bytes> = null;
                function addBundledEmoji() {
                    #if web
                    final face = glaze.platform.BundledEmojiFont.openBytes(emojiBytes);
                    emojiBytes = null;
                    #else
                    final face = glaze.platform.BundledEmojiFont.openFile(glaze.platform.BundledEmojiFont.filePath());
                    #end
                    if (face != null)
                        glaze.platform.BundledEmojiFont.addTo(glaze.App.defaultTextSystem().platformTextSystem, face);
                    else
                        log.warning('Failed to load the bundled emoji font ${glaze.platform.BundledEmojiFont.ASSET_PATH}');
                }
                function fontDone() {
                    pendingFonts--;
                    if (pendingFonts == 0)
                        addBundledEmoji();
                }
                #end

                #if !glaze_no_default_fonts
                // Bundled fonts (Inter and JetBrains Mono, SIL Open Font
                // License 1.1, see assets/glaze/fonts), added to the default
                // GPUI text system once loaded
                for (path in DEFAULT_FONTS) {
                    final asset = new BinaryAsset('glaze-font:' + path);
                    asset.path = path;
                    #if glaze_bundled_emoji
                    pendingFonts++;
                    #end
                    asset.onComplete(null, success -> {
                        if (success && asset.bytes != null) {
                            glaze.App.defaultTextSystem().addFonts([asset.bytes]);
                        }
                        else {
                            log.warning('Failed to load GPUI font $path');
                        }
                        #if glaze_bundled_emoji
                        fontDone();
                        #end
                    });
                    assets.addAsset(asset);
                }
                #end

                #if glaze_bundled_emoji
                #if web
                final emojiAsset = new BinaryAsset('glaze-font:' + glaze.platform.BundledEmojiFont.ASSET_PATH);
                emojiAsset.path = glaze.platform.BundledEmojiFont.ASSET_PATH;
                pendingFonts++;
                emojiAsset.onComplete(null, success -> {
                    emojiBytes = success ? emojiAsset.bytes : null;
                    fontDone();
                });
                assets.addAsset(emojiAsset);
                #end
                if (pendingFonts == 0)
                    addBundledEmoji();
                #end

                #if (js && glaze_onig_wasm)
                // vscode-oniguruma's onig.wasm as the code highlighter's
                // regex engine (copied into project/web by the build hook),
                // ready before the application starts
                assets.addAsset(new glaze.kit.highlighter.OnigWasm.OnigWasmAsset());
                #end
            });

        });

    }

}

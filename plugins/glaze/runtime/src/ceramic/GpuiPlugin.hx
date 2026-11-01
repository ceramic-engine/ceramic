package ceramic;

import ceramic.App;
import ceramic.Shortcuts.*;

/**
 * Runtime entry point of the `gpui` plugin.
 *
 * `pluginInit()` is called automatically by Ceramic's `PluginsMacro` (plugin name `Gpui`).
 */
@:access(ceramic.App)
class GpuiPlugin {

    /**
     * Fonts loaded with the default assets and added to
     * `gpui.App.defaultTextSystem()` (define `gpui_no_default_fonts` to skip).
     * `.SystemUIFont` is Inter.
     */
    public static final DEFAULT_FONTS:Array<String> = [
        'gpui/fonts/Inter-Regular.ttf.bin',
        'gpui/fonts/JetBrainsMono-Regular.ttf.bin'
    ];

    @:keep static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init gpui plugin (version ${gpui.Gpui.VERSION})');

            // GPUI scene shaders are loaded with the default assets,
            // so they are ready before the first scene is created
            App.app.onceDefaultAssetsLoad(null, function(assets) {
                assets.add(shaders.GpuiQuad);
                assets.add(shaders.GpuiShadow);
                assets.add(shaders.GpuiUnderline);
                assets.add(shaders.GpuiMonoSprite);
                assets.add(shaders.GpuiPolySprite);
                assets.add(shaders.GpuiPathSprite);

                #if !gpui_no_default_fonts
                // Bundled fonts (Inter and JetBrains Mono, SIL Open Font
                // License 1.1, see assets/gpui/fonts), added to the default
                // GPUI text system once loaded
                for (path in DEFAULT_FONTS) {
                    final asset = new BinaryAsset('gpui-font:' + path);
                    asset.path = path;
                    asset.onComplete(null, success -> {
                        if (success && asset.bytes != null) {
                            gpui.App.defaultTextSystem().addFonts([asset.bytes]);
                        }
                        else {
                            log.warning('Failed to load GPUI font $path');
                        }
                    });
                    assets.addAsset(asset);
                }
                #end

                #if (js && gpui_onig_wasm)
                // vscode-oniguruma's onig.wasm as the code highlighter's
                // regex engine (copied into project/web by the build hook),
                // ready before the application starts
                assets.addAsset(new gpui.component.highlighter.OnigWasm.OnigWasmAsset());
                #end
            });

        });

    }

}

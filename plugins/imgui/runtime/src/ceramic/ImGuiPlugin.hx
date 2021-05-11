package ceramic;

import ceramic.App;
import ceramic.Shortcuts.*;

using StringTools;

@:access(ceramic.App)
class ImGuiPlugin {

/// Init plugin
    
    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init imgui plugin');

            #if imgui_font
            // Load font for dear imgui
            ceramic.App.app.onceDefaultAssetsLoad(null, function(assets) {
                assets.add('binary:' + ceramic.macros.DefinesMacro.getDefine('imgui_font'));
            });
            #end

            app.loaders.push(initImGui);
            
        });

    }

    static function initImGui(done:Void->Void):Void {

        ImGuiSystem.shared.start(done);

    }

}

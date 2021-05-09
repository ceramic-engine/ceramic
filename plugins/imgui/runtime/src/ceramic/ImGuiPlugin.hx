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

            app.loaders.push(initImGui);
            
        });

    }

    static function initImGui(done:Void->Void):Void {

        ImGuiSystem.shared.start(done);

    }

}

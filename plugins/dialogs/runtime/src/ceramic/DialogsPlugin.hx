package ceramic;

import ceramic.App;
import ceramic.Entity;
import ceramic.Assets;
import ceramic.AssetOptions;
import ceramic.AssetId;
import ceramic.Asset;
import ceramic.Either;

import ceramic.Shortcuts.*;

using StringTools;

@:access(ceramic.App)
class DialogsPlugin {

/// Init plugin

    static function __init__():Void {

        // Calling a static method inside __init__ makes this snippet
        // compatible with haxe-modular or similar bundling tools
        DialogsPlugin.pluginInit();

    }
    
    static function pluginInit() {

        //

    }

}

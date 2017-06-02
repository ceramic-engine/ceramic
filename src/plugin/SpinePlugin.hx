package plugin;

import ceramic.App;
import ceramic.Entity;
import ceramic.Assets;
import ceramic.Shortcuts.*;

using StringTools;

// Expose API
typedef SpineData = plugin.spine.SpineData;
typedef SpineAsset = plugin.spine.SpineAsset;
typedef SpineTextureLoader = plugin.spine.SpineTextureLoader;

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('spine', ['spine'], true))
#end
class Spines {}

@:access(ceramic.App)
class SpinePlugin {

/// Init plugin

    static function __init__():Void {
        App.oncePreInit(function() {

            App.app.logger.log('Init spine plugin');

            // Extend assets with `spine` kind
            Assets.addAssetKind('spine', addSpine, ['spine'], true);

        });
    }

/// Asset extensions

    public static function addSpine(assets:Assets, name:String, ?options:AssetOptions):Void {

        if (name.startsWith('spine:')) name = name.substr(6);

        assets.addAsset(new SpineAsset(name, options));

    } //addSpine

} //SpinePlugin

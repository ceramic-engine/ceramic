package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Assets extends tools.Task {

/// Properties

/// Lifecycle

    override public function new() {

        super();

    } //new

    override public function info(cwd:String):String {

        return "Transform/copy project's assets for " + backend.name + " backend and given target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var availableTargets = backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);

        if (targetName == null) {
            fail('You must specify a target to transform/copy assets to.');
        }

        // Find target from name
        //
        var target = null;
        for (aTarget in availableTargets) {

            if (aTarget.name == targetName) {
                target = aTarget;
                break;
            }

        }

        if (target == null) {
            fail('Unknown target: $targetName');
        }

        // Compute all assets list
        var assets:Array<tools.Asset> = [];
        var assetsPath = Path.join([cwd, 'assets']);

        if (FileSystem.exists(assetsPath)) {
            for (name in Files.getFlatDirectory(assetsPath)) {

                assets.push(new tools.Asset(name, assetsPath));

            }
        }

        // Transform/copy assets
        var transformedAssets = backend.transformAssets(cwd, assets, target, settings.variant);

        if (transformedAssets.length > 0) {

            var dstAssetsPath = transformedAssets[0].rootDirectory;

            // Add _assets.json listing
            //
            var assetsJson:{assets:Array<{name:String}>} = {
                assets: []
            };

            for (asset in assets) {
                assetsJson.assets.push({
                    name: asset.name
                });
            }

            // Sort in order to have a predictible order
            assetsJson.assets.sort(function(a_:{name:String}, b_:{name:String}) {
                var a = a_.name.toLowerCase();
                var b = b_.name.toLowerCase();
                if (a < b) {
                    return -1;
                }
                else if (a > b) {
                    return 1;
                } else {
                    return 0;
                }
            });

            // Save file
            File.saveContent(
                Path.join([dstAssetsPath, '_assets.json']),
                Json.stringify(assetsJson, null, '    ')
            );
        }


        print('Updated project assets.');

    } //run

}
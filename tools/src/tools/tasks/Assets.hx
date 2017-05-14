package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.FileSystem;

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

        extractTargetDefines(cwd, args);

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

                assets.push(new tools.Asset(name, Path.join([assetsPath, name])));

            }
        }

        // Transform/copy assets
        backend.transformAssets(cwd, assets, target, settings.variant);

        print('Updated project assets.');

    } //run

}
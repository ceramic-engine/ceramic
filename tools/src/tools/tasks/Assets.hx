package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

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

        var fromArg = extractArgValue(args, 'from', true);
        var toArg = extractArgValue(args, 'to', true);
        var processIcons = false;

        var fromPath = null;
        var toPath = null;

        // We are either processing assets for current project
        // or with provided source and destination
        if (fromArg == null || toArg == null) {
            processIcons = true;
            ensureCeramicProject(cwd, args, App);
        }
        else {
            fromPath = fromArg;
            if (!Path.isAbsolute(fromPath)) {
                fromPath = Path.join([cwd, fromPath]);
            }
            toPath = toArg;
            if (!Path.isAbsolute(toPath)) {
                toPath = Path.join([cwd, toPath]);
            }

            if (!FileSystem.exists(fromPath)) {
                fail('Assets source directory doesn\'t exist: ' + fromPath);
            }
            if (!FileSystem.isDirectory(fromPath)) {
                fail('Assets source is not a directory: ' + fromPath);
            }
            if (FileSystem.exists(toPath) && !FileSystem.isDirectory(toPath)) {
                fail('Assets destination is not a directory: ' + toPath);
            }
        }

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

        // Are we only computing the json list or really processing all assets?
        var listOnly = extractArgFlag(args, 'list-only', true);

        // Compute all assets list
        var assets:Array<tools.Asset> = [];
        var ceramicAssetsPath = Path.join([context.ceramicPath, 'assets']);
        var assetsPath = Path.join([cwd, 'assets']);
        if (fromPath != null) {
            assetsPath = fromPath;
        }
        var names:Map<String,Bool> = new Map();

        // Add project assets
        if (FileSystem.exists(assetsPath)) {
            for (name in Files.getFlatDirectory(assetsPath)) {
                assets.push(new tools.Asset(name, assetsPath));
                names.set(name, true);
            }
        }

        // Add ceramic default assets (if not overrided by project assets)
        if (FileSystem.exists(ceramicAssetsPath)) {
            for (name in Files.getFlatDirectory(ceramicAssetsPath)) {
                if (!names.exists(name)) {
                    assets.push(new tools.Asset(name, ceramicAssetsPath));
                }
            }
        }

        // Transform/copy assets
        var transformedAssets = backend.transformAssets(
            cwd,
            assets,
            target,
            context.variant,
            listOnly,
            toPath
        );

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

            // Compare with previous file
            var assetsJsonPath = Path.join([dstAssetsPath, '_assets.json']);
            var assetsJsonString = Json.stringify(assetsJson, null, '    ');
            var prevAssetsJsonString = null;
            if (FileSystem.exists(assetsJsonPath)) {
                prevAssetsJsonString = File.getContent(assetsJsonPath);
            }

            // Save file if different
            if (assetsJsonString != prevAssetsJsonString) {
                File.saveContent(
                    assetsJsonPath,
                    assetsJsonString
                );
            }

            // Update icons
            if (processIcons) {
                var task = new Icons();
                task.run(cwd, [args[0], 'icons', target.name, '--variant', context.variant]);
            }
        }


        print('Updated project assets.');

    } //run

}
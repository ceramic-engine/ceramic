package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

class Assets extends tools.Task {

/// Properties

/// Lifecycle

    override public function new() {

        super();

    }

    override public function info(cwd:String):String {

        if (context.backend == null) {
            return "Transform/copy assets.";
        }
        else {
            return "Transform/copy project's assets for " + context.backend.name + " backend and given target.";
        }

    }

    override function run(cwd:String, args:Array<String>):Void {

        var filter = extractArgValue(args, 'filter');
        var regex = filter != null ? Glob.toEReg(filter) : null;

        var noBackendTransform = (context.backend == null) || extractArgFlag(args, 'no-backend-transform');

        var fromArg = extractArgValue(args, 'from', true);
        var toArg = extractArgValue(args, 'to', true);
        var processIcons = false;

        var isProjectAssets = false;

        var fromPath = null;
        var toPath = null;

        var project = null;

        var changedPaths:Array<String> = [];
        var listChanged = extractArgFlag(args, 'list-changed');

        // We are either processing assets for current project
        // or with provided source and destination
        if (fromArg == null || toArg == null) {
            isProjectAssets = true;
            processIcons = true;
            project = ensureCeramicProject(cwd, args, App);

            // Never filter when doing project assets
            filter = null;
            regex = null;
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

        var availableTargets = context.backend != null ? context.backend.getBuildTargets() : [];
        var targetName = context.backend != null ? getTargetName(args, availableTargets) : null;

        if (targetName == null && context.backend != null) {
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

        if (target == null && context.backend != null) {
            fail('Unknown target: $targetName');
        }

        // Are we only computing the json list or really processing all assets?
        var listOnly = extractArgFlag(args, 'list-only', true);

        // Compute all assets list
        var assets:Array<tools.Asset> = [];
        var ceramicAssetsPath = Path.join([context.ceramicToolsPath, 'assets']);
        var assetsPath = Path.join([cwd, 'assets']);
        if (fromPath != null) {
            assetsPath = fromPath;
        }
        var names:Map<String,Bool> = new Map();

        // Add assets
        if (FileSystem.exists(assetsPath)) {
            for (name in Files.getFlatDirectory(assetsPath)) {
                if (regex == null || regex.match(name)) {
                    assets.push(new tools.Asset(name, assetsPath));
                    names.set(name, true);
                }
            }
        }

        // Compute destination assets path
        var dstAssetsPath = toPath;
        var transformedAssetsPath = null;
        if (!noBackendTransform) {
            if (dstAssetsPath == null) {
                dstAssetsPath = context.backend.getDstAssetsPath(
                    cwd,
                    target,
                    context.variant
                );
            }
            if (transformedAssetsPath == null) {
                transformedAssetsPath = context.backend.getTransformedAssetsPath(
                    cwd,
                    target,
                    context.variant
                );
            }
        }
        else if (transformedAssetsPath == null && !isProjectAssets && toPath != null) {
            transformedAssetsPath = toPath;
        }
        else {
            transformedAssetsPath = TempDirectory.tempDir('transformedAssets');
            context.tempDirs.push(transformedAssetsPath);
        }

        // If no specific path is specified, that means we are
        // transforming project's assets, so let's involve every extra asset path
        // including the ones provided by plugins
        if (isProjectAssets) {

            print('Update project assets');

            // Add extra asset paths
            if (project != null) {
                var extraAssets:Array<String> = project.app.assets;
                if (extraAssets != null) {
                    for (extraAssetsPath in extraAssets) {
                        if (FileSystem.exists(extraAssetsPath) && FileSystem.isDirectory(extraAssetsPath)) {
                            for (name in Files.getFlatDirectory(extraAssetsPath)) {
                                if (!names.exists(name)) {
                                    if (regex == null || regex.match(name)) {
                                        assets.push(new tools.Asset(name, extraAssetsPath));
                                        names.set(name, true);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Add ceramic default assets (if not overrided by project or plugins assets)
            if (FileSystem.exists(ceramicAssetsPath)) {
                for (name in Files.getFlatDirectory(ceramicAssetsPath)) {
                    if (!names.exists(name)) {
                        if (regex == null || regex.match(name)) {
                            assets.push(new tools.Asset(name, ceramicAssetsPath));
                        }
                    }
                }
            }
        }
        else {
            // In other situations, we are explicitly processing assets from and to specific paths
        }

        // Transform assets with high level transformers
        if (!FileSystem.exists(transformedAssetsPath)) {
            FileSystem.createDirectory(transformedAssetsPath);
        }
        var transformedAssets = assets;
        for (transformer in context.assetsTransformers) {
            transformedAssets = transformer.transform(transformedAssets, transformedAssetsPath, changedPaths);
        }

        if (!noBackendTransform) {
            // Transform/copy assets with backend
            transformedAssets = context.backend.transformAssets(
                cwd,
                transformedAssets,
                target,
                context.variant,
                listOnly,
                toPath
            );
        }

        if (isProjectAssets && transformedAssets.length > 0 && dstAssetsPath != null) {

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
                if (!FileSystem.exists(dstAssetsPath)) {
                    FileSystem.createDirectory(dstAssetsPath);
                }
                File.saveContent(
                    assetsJsonPath,
                    assetsJsonString
                );
            }

            // Update icons
            if (processIcons) {
                var task = new Icons();
                task.run(cwd, ['icons', target.name, '--variant', context.variant]);
            }
        }

        if (isProjectAssets && context.backend != null && (context.assetsChanged || context.iconsChanged)) {
            // Invalidate project files last modified times because assets or icons have changed
            // in order to ensure build will be reprocessed again
            var outPath = target.outPath(context.backend.name, cwd, context.debug, context.variant);
            var lastModifiedListFile = Path.join([outPath, 'lastModifiedList.json']);
            if (FileSystem.exists(lastModifiedListFile)) {
                FileSystem.deleteFile(lastModifiedListFile);
            }
            var lastModifiedListFileDebug = Path.join([outPath, 'lastModifiedList-debug.json']);
            if (FileSystem.exists(lastModifiedListFileDebug)) {
                FileSystem.deleteFile(lastModifiedListFileDebug);
            }
        }

        if (listChanged) {
            print(Json.stringify(changedPaths));
        }

    }

}
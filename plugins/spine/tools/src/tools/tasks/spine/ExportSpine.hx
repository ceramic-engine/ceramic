package tools.tasks.spine;

import haxe.DynamicAccess;
import haxe.Json;
import haxe.crypto.Md5;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class ExportSpine extends tools.Task {

    override public function info(cwd:String):String {

        return "Export spine animations from a Spine project to usable assets.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        // Get project info
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        var projectCachePath = Path.join([cwd, '.cache']);
        var tmpPath = Path.join([cwd, '.tmp']);
        var spineDefaultConfigPath = Path.join([cwd, 'resources/spine-config.json']);
        var project = new tools.Project();
        var force = extractArgFlag(args, 'force');
        var stripAnimFolders = extractArgFlag(args, 'strip-animation-folders');
        var stripSkinFolders = extractArgFlag(args, 'strip-skin-folders');
        var prettyPrint = extractArgFlag(args, 'pretty');
        var spineVersion = extractArgValue(args, 'version');
        project.loadAppFile(projectPath);

        if (project.app.spine == null || !Std.isOfType(project.app.spine.export, Array)) {
            fail('Missing spine export option in ceramic.yml file like:

    spine:
        export:
            - path/to/Project.spine

');
        }

        if (spineVersion == null) {
            if (project.app.spine.version != null) {
                spineVersion = ''+project.app.spine.version;
            }
        }

        if (!FileSystem.exists(tmpPath)) {
            FileSystem.createDirectory(tmpPath);
        }

        var hasExplicitSpineCmd = (project.app.spine.command != null && project.app.spine.command is String);

        var spineCmdPath:String = null;
        if (Sys.systemName() == 'Mac') {
            spineCmdPath = '/Applications/Spine.app/Contents/MacOS/Spine';
        } else if (Sys.systemName() == 'Windows') {
            for (drive in getWindowsDrives()) {
                for (programFiles in ['Program Files', 'Program Files (x86)']) {
                    var tryPath = '$drive:\\$programFiles\\Spine\\Spine.com';
                    if (FileSystem.exists(tryPath)) {
                        spineCmdPath = tryPath;
                        break;
                    }
                }
            }
            if (spineCmdPath == null && !hasExplicitSpineCmd) {
                fail('Failed to resolve spine export command. You might need to explicitly specify it in ceramic.yml.');
            }
        } else {
            if (hasExplicitSpineCmd) {
                // Will use explicit command path
            }
            else {
                fail('Spine export command must be specified explicitly in ceramic.yml on ' + Sys.systemName() + ' system.');
            }
        }

        // Explicit spine path
        if (hasExplicitSpineCmd) {
            spineCmdPath = project.app.spine.command;
        }

        if (!FileSystem.exists(spineCmdPath)) {
            fail('Invalid spine export command path: $spineCmdPath');
        }

        var exportList:Array<Dynamic> = project.app.spine.export;
        for (rawItem in exportList) {

            var spineConfigPath:String = null;
            var rename:DynamicAccess<String> = null;
            var outputDir:String = 'assets';

            var path:String = null;
            if (Std.isOfType(rawItem, String)) {
                path = rawItem;
            } else {
                path = rawItem.path;
                if (rawItem.config != null) {
                    print('Use custom config: ' + rawItem.config);
                    spineConfigPath = Path.join([cwd, 'resources/' + rawItem.config]);
                }
                if (rawItem.rename != null) {
                    print('Rename:');
                    rename = rawItem.rename;
                    for (key in rename.keys()) {
                        print('  $key -> ${rename.get(key)}');
                    }
                }
                if (rawItem.output != null) {
					print('Export to directory: '+rawItem.output);
                    outputDir = rawItem.output;
				}
            }

            if (path == null) {
                fail('Missing spine project path');
            }

            if (spineConfigPath == null) {
                if (!FileSystem.exists(spineDefaultConfigPath)) {
                    fail('Missing Spine export config file at resources/spine-config.json');
                }
                spineConfigPath = spineDefaultConfigPath;
            }
            else {
                if (!FileSystem.exists(spineConfigPath)) {
                    fail('Missing Spine export config file at ' + rawItem.config);
                }
            }

            var spineConfig:Dynamic = null;
            try {
                spineConfig = Json.parse(File.getContent(spineConfigPath));
            }
            catch (e:Dynamic) {
                fail('Failed to parse spine export config file: ' + e);
            }

            if (!Path.isAbsolute(path)) path = Path.join([cwd, path]);

            // Create export config
            var exportPath = Path.join([tmpPath, 'spine']);
            spineConfig.project = path;
            spineConfig.input = path;
            spineConfig.output = exportPath;

            // Compute absolute spine project path
            var spineProjectPath = path;
            if (!Path.isAbsolute(spineProjectPath)) {
                spineProjectPath = Path.join([context.cwd, spineProjectPath]);
            }

            var projectKey = Md5.encode('spine:'+path);
            var projectKeyPath = Path.join([projectCachePath, projectKey]);
            if (!force) {
                // Check last modified date to see if this entry needs to be converted again or not
                if (FileSystem.exists(projectKeyPath)) {
                    if (Files.haveSameLastModified(spineProjectPath, projectKeyPath)) {
                        print('Skip ' + path);
                        continue;
                    }
                }
            }

            // Save export config for use right after
            var tmpConfigPath = Path.join([tmpPath, 'spine-config.json']);
            File.saveContent(tmpConfigPath, Json.stringify(spineConfig, null, '  '));

            // Remove any previously exported files
            if (FileSystem.exists(exportPath)) {
                Files.deleteRecursive(exportPath);
            }

            FileSystem.createDirectory(exportPath);

            // Configure cli args
            var cmdArgs = ['--export', tmpConfigPath];

            if (spineVersion != null) {
                cmdArgs = ['--update', spineVersion].concat(cmdArgs);
            }

            // Export
            command(spineCmdPath, cmdArgs);

            // Move files to assets directory
            //
            var skeletons:Map<String,Array<String>> = new Map();
            var flatExportList = Files.getFlatDirectory(exportPath);
            var atlasPages = new Map<String,Array<String>>();

            for (item in flatExportList) {
                var isAtlas = RE_ATLAS.match(item);
                if (isAtlas) {
                    atlasPages.set(item, extractImageNames(File.getContent(Path.join([exportPath, item]))));
                }
            }

            for (item in flatExportList) {

                var name = Path.withoutDirectory(Path.withoutExtension(item));

                if (RE_PNG.match(item)) {
                    var pngFileName = Path.withoutDirectory(item);
                    for (atlasName => pages in atlasPages) {
                        if (pages.indexOf(pngFileName) != -1) {
                            name = Path.withoutDirectory(Path.withoutExtension(atlasName));
                            break;
                        }
                    }
                }

                if (name.indexOf('@') != -1) name = name.substring(0, name.indexOf('@'));

                if (rename != null && rename.exists(name))
                    name = rename.get(name);

                var entries = skeletons.get(name);
                if (entries == null) {
                    entries = [];
                    skeletons.set(name, entries);
                }
                entries.push(item);
            }

            // Gather atlas info
            //
            var skeletonAtlases = new Map<String,Array<String>>();

            for (groupName in skeletons.keys()) {
                var groupDirRelative = groupName + '.spine';

                for (name in skeletons.get(groupName)) {
                    var outName = convertName(name);
                    var ext = Path.extension(outName);

                    if (ext == 'atlas') {
                        var atlases = skeletonAtlases.get(groupName);
                        if (atlases == null) {
                            atlases = [];
                            skeletonAtlases.set(groupName, atlases);
                        }
                        atlases.push(Path.join([groupDirRelative, outName]));
                    }
                }

            }

            // Do the actual moving
            //
            for (groupName in skeletons.keys()) {
                print('Add ' + outputDir + '/' + groupName + '.spine');

                var groupDir = Path.join([cwd, outputDir, groupName + '.spine']);

                if (FileSystem.exists(groupDir)) {
                    Files.deleteRecursive(groupDir);
                }
                FileSystem.createDirectory(groupDir);

                // Ensure suffixes generated by spine will
                // match ceramic's asset naming system
                for (name in skeletons.get(groupName)) {

                    var outName = convertName(name);
                    var ext = Path.extension(outName);

                    if (ext == 'atlas') {
                        // Convert atlas
                        var atlasContent = File.getContent(Path.join([tmpPath, 'spine', name]));

                        atlasContent = convertAtlas(atlasContent);
                        File.saveContent(Path.join([groupDir, outName]), atlasContent);

                    }
                    else if (ext == 'json') {
                        // Patch json if needed
                        var jsonContent = File.getContent(Path.join([tmpPath, 'spine', name]));
                        var parsed = Json.parse(jsonContent);

                        // Strip skin folders in names?
                        if (stripSkinFolders) {
                            if (parsed.skins != null) {
                                var usedSkinNames = new Map<String,Bool>();
                                var skins:Array<{name:String,attachments:Dynamic}> = parsed.skins;
                                for (skin in skins) {
                                    var lastSlashIndex = skin.name.lastIndexOf('/');
                                    if (lastSlashIndex != -1) {
                                        skin.name = skin.name.substring(lastSlashIndex + 1);
                                    }
                                    if (usedSkinNames.exists(skin.name)) {
                                        fail('Duplicate skin name: ${skin.name} (skeleton: $name)');
                                    }
                                    usedSkinNames.set(skin.name, true);

                                    // Attachments
                                    if (skin.attachments != null) {
                                        for (k1 in Reflect.fields(skin.attachments)) {
                                            var val = Reflect.field(skin.attachments, k1);
                                            for (k2 in Reflect.fields(val)) {
                                                var v:{skin:String} = Reflect.field(val, k2);
                                                if (v.skin != null) {
                                                    var lastSlashIndex = v.skin.lastIndexOf('/');
                                                    if (lastSlashIndex != -1) {
                                                        v.skin = v.skin.substring(lastSlashIndex + 1);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Update animations referencing skins
                                if (parsed.animations != null) {
                                    for (key in Reflect.fields(parsed.animations)) {
                                        var animation = Reflect.field(parsed.animations, key);

                                        // Deform
                                        if (animation.deform != null) {
                                            for (k in Reflect.fields(animation.deform)) {
                                                var newKey = k;
                                                var lastSlashIndex = k.lastIndexOf('/');
                                                if (lastSlashIndex != -1) {
                                                    newKey = k.substring(lastSlashIndex + 1);
                                                    Reflect.setField(animation.deform, newKey, Reflect.field(animation.deform, k));
                                                    Reflect.deleteField(animation.deform, k);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Strip anim folders in names?
                        if (stripAnimFolders) {
                            if (parsed.animations != null) {
                                for (key in Reflect.fields(parsed.animations)) {
                                    var newKey = key;
                                    var lastSlashIndex = key.lastIndexOf('/');
                                    if (lastSlashIndex != -1) {
                                        newKey = key.substring(lastSlashIndex + 1);
                                    }
                                    if (newKey != key) {
                                        if (Reflect.field(parsed.animations, newKey) != null) {
                                            fail('Duplicate animation name: $newKey (skeleton: $name)');
                                        }
                                        Reflect.setField(parsed.animations, newKey, Reflect.field(parsed.animations, key));
                                        Reflect.deleteField(parsed.animations, key);
                                    }
                                }
                            }
                        }

                        // Save content
                        File.saveContent(Path.join([groupDir, outName]), prettyPrint ? Json.stringify(parsed, null, '    ') : Json.stringify(parsed));
                    }
                    else {
                        // Just copy
                        File.copy(
                            Path.join([tmpPath, 'spine', name]),
                            Path.join([groupDir, outName])
                        );
                    }
                }

                // Link to another atlas if needed
                if (!skeletonAtlases.exists(groupName)) {
                    for (atlasKey in skeletonAtlases.keys()) {
                        var atlases = skeletonAtlases.get(atlasKey);
                        for (atlas in atlases) {
                            var name = Path.withoutDirectory(atlas);
                            var suffix = name.substring(atlasKey.length);
                            File.saveContent(Path.join([groupDir, groupName + suffix]), 'alias:' + atlas);
                        }
                        // No need to iterate more
                        break;
                    }
                }
            }

            // Keep a local cache file to track which asset will need to be updated next time
            if (!FileSystem.exists(projectCachePath)) {
                FileSystem.createDirectory(projectCachePath);
            }
            File.saveContent(projectKeyPath, path);
            Files.setToSameLastModified(spineProjectPath, projectKeyPath);

        }

        // Cleanup
        Files.deleteRecursive(tmpPath);

    }

    function convertName(inName:String) {

        if (RE_SCALE_SUFFIX.match(inName)) {
            inName = inName.substring(RE_SCALE_SUFFIX.matched(1).length);
        }

        var withoutExt = Path.withoutExtension(inName);
        var ext = Path.extension(inName);
        if (RE_AT_NX.match(withoutExt)) {
            withoutExt = withoutExt.substring(0, withoutExt.length - RE_AT_NX.matched(0).length);
            if (RE_AT_NX.matched(2) != null) {
                withoutExt += RE_AT_NX.matched(2);
            }
            withoutExt += '@' + RE_AT_NX.matched(1);
            return withoutExt + 'x.' + ext;
        }
        else {
            return inName;
        }

    }

    function convertAtlas(inAtlas:String) {

        var lines = inAtlas.replace("\r",'').split("\n");
        var newLines = [];
        var previousIsBlank = true;
        for (line in lines) {
            if (previousIsBlank && RE_PNG.match(line)) {
                line = convertName(line);
                previousIsBlank = false;
            }
            else if (line.trim().length == 0) {
                previousIsBlank = true;
            }
            else {
                previousIsBlank = false;
            }
            newLines.push(line);
        }

        return newLines.join("\n");

    }

    function extractImageNames(atlas:String) {

        var lines = atlas.replace("\r",'').split("\n");
        var result = [];
        var previousIsBlank = true;
        for (line in lines) {
            if (previousIsBlank && RE_PNG.match(line)) {
                result.push(line.trim());
                previousIsBlank = false;
            }
            else if (line.trim().length == 0) {
                previousIsBlank = true;
            }
            else {
                previousIsBlank = false;
            }
        }

        return result;

    }

    static var RE_AT_NX = ~/@([0-9]+(?:\.[0-9]+)?)x(_?[0-9]+)?$/;
    static var RE_SCALE_SUFFIX = ~/^([0-9]+(\.[0-9]+)?(\/|\\))/;
    static var RE_PNG = ~/\.(png|PNG)$/;
    static var RE_ATLAS = ~/\.(atlas|ATLAS)$/;

}

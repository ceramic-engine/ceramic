package tools;

import haxe.io.Path;
import sys.FileSystem;
import tools.Files;
import tools.Helpers.*;
import tools.Project;
import tools.Templates;

class MacApp {

    /**
     * Name of the app bundle folder in `project/mac`. The template's
     * `myapp.app` is renamed with the app name lowercased, so every path to
     * the bundle must use this name: `project.app.name + '.app'` only finds
     * it on a case insensitive volume.
     */
    public static function appBundleName(project:Project):String {

        return ('' + project.app.name).toLowerCase() + '.app';

    }

    /**
     * Path of the app bundle in `project/mac` (see `appBundleName()`).
     */
    public static function appPath(cwd:String, project:Project):String {

        return Path.join([cwd, 'project', 'mac', appBundleName(project)]);

    }

    public static function createMacAppIfNeeded(cwd:String, project:Project):Void {

        var macProjectPath = Path.join([cwd, 'project/mac']);
        var defaultMacAppPath = Path.join([macProjectPath, 'myapp.app']);
        var macAppPath = appPath(cwd, project);
        var macAppInfoFile = Path.join([macAppPath, 'Contents', 'Info.plist']);
        var macAppAssetsPath = Path.join([macAppPath, 'Contents', 'Resources', 'assets']);
        var tmpAppAssetsPath = Path.join([cwd, 'project', 'mac-tmp-assets']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(macAppInfoFile)) {

            // We are expecting assets to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(macAppAssetsPath)) {
                if (FileSystem.exists(tmpAppAssetsPath)) {
                    Files.deleteRecursive(tmpAppAssetsPath);
                }
                FileSystem.rename(macAppAssetsPath, tmpAppAssetsPath);
            }

            // Cleanup before copying
            Files.deleteRecursive(macAppPath);

            // Plugin path
            var pluginPath = context.plugins.get('mac').path;

            // Create directory if needed
            if (!FileSystem.exists(macProjectPath)) {
                FileSystem.createDirectory(macProjectPath);
            }

            // Copy from template project
            print('Copy from Mac project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project/mac']),
                macProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInNames['MyApp'] = project.app.name;
            replacementsInNames['myapp'] = (''+project.app.name).toLowerCase();
            Templates.replaceInNames(macProjectPath, replacementsInNames);

            // Replace in contents
            print('Perform replaces in contents');
            var replacementsInContents = new Map<String,String>();
            if (project.app.company != null) {
                replacementsInContents['My Company'] = project.app.company;
            }
            else if (project.app.author != null) {
                replacementsInContents['My Company'] = project.app.author;
            }
            replacementsInContents['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInContents['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInContents['MyApp'] = project.app.name;
            replacementsInContents['My App'] = project.app.displayName;
            replacementsInContents['myapp'] = (''+project.app.name).toLowerCase();
            Templates.replaceInContents(macProjectPath, replacementsInContents);

            // Delete remaining template folders, if any
            if (FileSystem.exists(defaultMacAppPath) && FileSystem.isDirectory(defaultMacAppPath)) {
                Files.deleteRecursive(defaultMacAppPath);
            }

            // Put assets back
            if (FileSystem.exists(tmpAppAssetsPath)) {
                if (FileSystem.exists(macAppAssetsPath)) {
                    Files.deleteRecursive(macAppAssetsPath);
                }
                FileSystem.rename(tmpAppAssetsPath, macAppAssetsPath);
            }
        }

        applyDisplayName(macAppInfoFile, project);
        applyCategory(macAppInfoFile, project);
        applyIcon(cwd, macAppPath, project);

    }

    /**
     * Writes `app.displayName` of `ceramic.yml` in `CFBundleName` (the title
     * of the app's menu in the menu bar) and `CFBundleDisplayName` of the
     * bundle's Info.plist, at every build so that an existing project follows
     * a change. Projects made from an older template had the lowercased app
     * name in `CFBundleName`.
     */
    static function applyDisplayName(infoPlistPath:String, project:Project):Void {

        var displayName:Null<String> = project.app.displayName;
        if (displayName == null || StringTools.trim(displayName) == '' || !FileSystem.exists(infoPlistPath)) return;

        var value = StringTools.replace(displayName, '&', '&amp;');
        value = StringTools.replace(value, '<', '&lt;');
        value = StringTools.replace(value, '>', '&gt;');

        var content = sys.io.File.getContent(infoPlistPath);
        var updated = content;
        for (key in ['CFBundleName', 'CFBundleDisplayName']) {
            var re = new EReg('(<key>' + key + '</key>\\s*<string>)([^<]*)(</string>)', '');
            if (re.match(updated)) {
                if (re.matched(2) != value) {
                    updated = re.matchedLeft() + re.matched(1) + value + re.matched(3) + re.matchedRight();
                }
            }
            else {
                // Only the first <dict>, the root one
                var at = updated.indexOf('<dict>');
                if (at == -1) continue;
                at += '<dict>'.length;
                updated = updated.substring(0, at) + '\n    <key>' + key + '</key>\n    <string>' + value + '</string>' + updated.substring(at);
            }
        }
        if (updated != content) {
            sys.io.File.saveContent(infoPlistPath, updated);
        }

    }

    /**
     * Copies `project/mac/app.icns` (made from `app.iconMac` by the icons
     * task) to the bundle's `Contents/Resources/app.icns`, the icon the
     * template's Info.plist names, at every build. When it changes, the
     * bundle is touched so that the Dock and the Finder read it again.
     */
    static function applyIcon(cwd:String, macAppPath:String, project:Project):Void {

        var icon = Path.join([cwd, 'project', 'mac', 'app.icns']);
        var resourcesPath = Path.join([macAppPath, 'Contents', 'Resources']);
        if (!FileSystem.exists(icon) || !FileSystem.exists(resourcesPath)) return;
        var target = Path.join([resourcesPath, 'app.icns']);
        var bytes = sys.io.File.getBytes(icon);
        if (FileSystem.exists(target) && sys.io.File.getBytes(target).compare(bytes) == 0) return;

        sys.io.File.saveBytes(target, bytes);
        command('touch', [macAppPath], { mute: true });

    }

    /**
     * Writes `app.macCategory` of `ceramic.yml` (a value of
     * `LSApplicationCategoryType`, like `public.app-category.productivity`)
     * in the bundle's Info.plist, at every build so that an existing project
     * follows a change. Without it the template's value stays
     * (`public.app-category.games`, which lets macOS turn Game Mode on for
     * the app).
     */
    static function applyCategory(infoPlistPath:String, project:Project):Void {

        var category:Null<String> = Reflect.field(project.app, 'macCategory');
        if (category == null || StringTools.trim(category) == '' || !FileSystem.exists(infoPlistPath)) return;

        var content = sys.io.File.getContent(infoPlistPath);
        var re = ~/(<key>LSApplicationCategoryType<\/key>\s*<string>)([^<]*)(<\/string>)/;
        var updated = if (re.match(content)) {
            if (re.matched(2) == category) return;
            re.matchedLeft() + re.matched(1) + category + re.matched(3) + re.matchedRight();
        }
        else {
            StringTools.replace(content, '<dict>', '<dict>\n    <key>LSApplicationCategoryType</key>\n    <string>' + category + '</string>');
        }
        sys.io.File.saveContent(infoPlistPath, updated);

    }

}

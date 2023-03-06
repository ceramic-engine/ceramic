package tools;

import haxe.Json;
import haxe.io.Path;
import npm.Yaml;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

enum PluginKind {
    Runtime;
    Tools;
    Editor;
}

enum ProjectKind {
    App;
    Plugin(kinds:Array<PluginKind>);
}

typedef ProjectFormat = {
    @:optional var name:String;
    @:optional var displayName:String;
    @:optional var author:String;
    @:optional var version:String;
}

typedef ProjectApp = {
    > ProjectFormat,
}

typedef ProjectPlugin = {
    > ProjectFormat,
}

class Project {

    /** A list of haxe libraryes required to make ceramic runtime work */
    public static var runtimeLibraries:Array<Dynamic> = [
        'format',
        'hscript',
        'bind',
        'polyline',
        'tracker',
        'earcut',
        'poly2tri',
        'hsluv'
    ];

/// Properties

    // TODO use project format typedefs

    public var app:Dynamic<Dynamic>;

    public var plugin:Dynamic<Dynamic>;

/// Lifecycle

    public function new():Void {

    }

    public function getKind(path:String):ProjectKind {

        if (app != null) return App;
        if (plugin != null) return Plugin([]);

        if (!FileSystem.exists(path)) {
            fail('There is no app project file at path: $path');
        }

        if (FileSystem.isDirectory(path)) {
            fail('A directory is not a valid ceramic project path at: $path');
        }

        var data:String = null;
        try {
            data = File.getContent(path).replace('{plugin:cwd}', context.cwd).replace('{cwd}', context.cwd);
        }
        catch (e:Dynamic) {
            fail('Unable to read project at path $path: $e');
        }

        // Parse YAML
        //
        try {
            var parsed = Yaml.parse(data);

            if (parsed.app == null) {
                if (parsed.plugin != null) {
                    return Plugin([]);
                } else {
                    return null;
                }
            } else {
                return App;
            }

            app = parsed.app;
        }
        catch (e:Dynamic) {
            fail("Error when parsing project YAML: " + e);
        }

        fail('Unable to retrieve project kind.');
        return null;

    }

    public function loadAppFile(path:String):Void {

        if (!FileSystem.exists(path)) {
            fail('There is no app project file at path: $path');
        }

        if (FileSystem.isDirectory(path)) {
            fail('A directory is not a valid app project path at: $path');
        }

        var data:String = null;
        try {
            data = File.getContent(path).replace('{plugin:cwd}', context.cwd).replace('{cwd}', context.cwd);
        }
        catch (e:Dynamic) {
            fail('Unable to read project at path $path: $e');
        }

        app = ProjectLoader.loadAppConfig(data, context.defines, context.plugins, context.unbuiltPlugins);

        // Add path
        app.path = Path.isAbsolute(path) ? path : Path.normalize(Path.join([context.cwd, path]));

        // Extend app config from tools plugin code
        if (context.plugins != null) {
            for (plugin in context.plugins) {
                if (plugin.extendProject != null) {

                    var prevPlugin = context.plugin;
                    context.plugin = plugin;

                    plugin.extendProject(this);

                    context.plugin = prevPlugin;
                }
            }
        }

        app.editable.push('ceramic.Entity');

        app.editable.push('ceramic.Visual');
        app.editable.push('ceramic.Layer');
        app.editable.push('ceramic.Fragment');
        app.editable.push('ceramic.Quad');
        app.editable.push('ceramic.Text');
        app.editable.push('ceramic.Mesh');
        app.editable.push('ceramic.Shape');
        app.editable.push('ceramic.Ngon');
        app.editable.push('ceramic.Arc');
        app.editable.push('ceramic.Line');
        app.editable.push('ceramic.Particles');

        if (app.hxml == null) app.hxml = '';

        var appInfo:Dynamic = {};
        if (Reflect.field(app, 'package') != null)
            Reflect.setField(appInfo, 'package', Reflect.field(appInfo, 'package'));
        if (app.name != null)
            appInfo.name = app.name;
        if (app.displayName != null)
            appInfo.displayName = app.displayName;
        if (app.author != null)
            appInfo.author = app.author;
        if (app.version != null)
            appInfo.version = app.version;
        if (app.collections != null)
            appInfo.collections = app.collections;
        if (app.editable != null)
            appInfo.editable = app.editable;

        app.hxml += "\n" + "-D app_info=" + Json.stringify(Json.stringify(appInfo));
        app.hxml += "\n" + "--macro ceramic.macros.MacroCache.init()";

        app.hxml += '\n' + '-D tracker_ceramic';
        app.hxml += '\n' + '-D tracker_no_default_backend';
        app.hxml += '\n' + '-D tracker_custom_entity=ceramic.Entity';
        app.hxml += '\n' + '-D tracker_custom_component=ceramic.Component';
        app.hxml += '\n' + '-D tracker_custom_array_pool=ceramic.ArrayPool';
        app.hxml += '\n' + '-D tracker_custom_backend=ceramic.TrackerBackend';
        app.hxml += '\n' + '-D tracker_custom_reusable_array=ceramic.ReusableArray';
        // app.hxml += '\n' + '--macro tracker.macros.TrackerMacro.setEntity("ceramic.Entity")';
        // app.hxml += '\n' + '--macro tracker.macros.TrackerMacro.setComponent("ceramic.Component")';
        // app.hxml += '\n' + '--macro tracker.macros.TrackerMacro.setBackend("ceramic.TrackerBackend")';
        // app.hxml += '\n' + '--macro tracker.macros.TrackerMacro.setArrayPool("ceramic.ArrayPool")';
        // app.hxml += '\n' + '--macro tracker.macros.TrackerMacro.setReusableArray("ceramic.ReusableArray")';

        if (context.defines.exists('android')) {
            app.hxml += "\n" + "-D NO_PRECOMPILED_HEADERS";
        }

    }

    public function loadPluginFile(path:String):Void {

        if (!FileSystem.exists(path)) {
            fail('There is no plugin project file at path: $path');
        }

        if (FileSystem.isDirectory(path)) {
            fail('A directory is not a valid plugin project path at: $path');
        }

        var data:String = null;
        try {
            data = File.getContent(path)
                .replace('{plugin:cwd}', Path.directory(path))
                .replace('{cwd}', context.cwd)
            ;
        }
        catch (e:Dynamic) {
            fail('Unable to read project at path $path: $e');
        }

        plugin = ProjectLoader.loadPluginConfig(data, context.defines);

        // Add path
        plugin.path = Path.isAbsolute(path) ? path : Path.normalize(Path.join([context.cwd, path]));

    }

/// Utilities

    public function sharedHxml():Array<String> {

        if (app != null) {

            return [
                // Needed to workaround some edge case on type resolution in StateMachineMacro
                // in case the state machine is created inside a `components` package.
                '--remap components_:components'
            ];

        }

        return [];

    }

}

/** Parsing/loading code to read ceramic project format. */
class ProjectLoader {

    static var RE_ALNUM_CHAR = ~/^[a-zA-Z0-9_]$/g;

    static var RE_IDENTIFIER = ~/^[a-zA-Z_][a-zA-Z0-9_]*$/g;

    public static function loadAppConfig(
        input:String,
        defines:Map<String,String>,
        plugins:Map<String, tools.spec.ToolsPlugin>,
        unbuiltPlugins:Map<String, {path:String, name:String, runtime:Dynamic}>
    ):Dynamic<Dynamic> {

        var app:Dynamic<Dynamic> = null;

        // Parse YAML
        //
        try {
            var parsed = Yaml.parse(input);

            if (parsed.app == null) {
                if (parsed.plugin != null) {
                    fail('This project is not a ceramic app project. Is it a plugin project?');
                } else {
                    fail('This project is not a ceramic app project.');
                }
            }

            app = parsed.app;
        }
        catch (e:Dynamic) {
            fail("Error when parsing project YAML: " + e);
        }

        try {

            // Update defines from app
            //
            /*var newDefines = new Map<String,String>();
            for (key in defines.keys()) {
                newDefines.set(key, defines.get(key));
            }
            defines = newDefines;*/

            // Defines (before evaluating conditions)
            if (app.defines != null) {
                if (Std.isOfType(app.defines, Array)) {
                    var appDefinesList:Array<Dynamic> = app.defines;
                    app.defines = {};
                    for (item in appDefinesList) {
                        if (Std.isOfType(item, String) || Std.isOfType(item, Bool) || Std.isOfType(item, Float) || Std.isOfType(item, Int)) {
                            Reflect.setField(app.defines, item, true);
                        } else {
                            for (key in Reflect.fields(item)) {
                                Reflect.setField(app.defines, key, Reflect.field(item, key));
                            }
                        }
                    }
                }
                for (key in Reflect.fields(app.defines)) {
                    if (!defines.exists(key)) {
                        var val = Reflect.field(app.defines, key);
                        defines.set(key, val == true ? '' : '' + val);
                    }
                }
            }
            else {
                app.defines = {};
            }

            // Extract enabled plugins
            var enabledPlugins = extractEnabledPlugins(app, defines);

            // Create `plugin_{plugin}` define from every plugin entry explicitly put in project file
            if (enabledPlugins != null && enabledPlugins.length > 0) {
                for (pluginName in enabledPlugins) {
                    var key = 'plugin_' + pluginName;
                    if (!defines.exists(key)) {
                        defines.set(key, '');
                    }
                }
            }

            // Add plugin runtime extra config
            var pluginI = 0;
            if (plugins != null) {
                for (plugin in plugins) {
                    if (plugin.runtime != null) {
                        Reflect.setField(
                            app,
                            'if true || plugin_runtime_' + (pluginI++),
                            Json.parse(Json.stringify(plugin.runtime)) // Copy to prevent plugin to be modified
                        );
                    }
                }
            }

            // Also use unbuilt plugins for runtime info
            // (unbuilt plugin include plugins without any tool extension)
            if (unbuiltPlugins != null) {
                for (plugin in unbuiltPlugins) {
                    if (plugin.runtime != null) {
                        Reflect.setField(
                            app,
                            'if true || plugin_runtime_' + (pluginI++),
                            Json.parse(Json.stringify(plugin.runtime)) // Copy to prevent plugin to be modified
                        );
                    }
                }
            }

            inline function ensureDefaultConfig() {
                // Add additional/default config
                if (app.generated == null) {
                    app.generated = [];
                }
                if (app.libs == null) {
                    app.libs = [];
                }
                if (app.paths == null) {
                    app.paths = [];
                }
                if (app.editable == null) {
                    app.editable = [];
                }
                if (app.hooks == null) {
                    app.hooks = [];
                }
            }

            ensureDefaultConfig();

            // Evaluate conditionals
            evaluateConditionals(app, defines, true);

            ensureDefaultConfig();

            // Add required libs
            for (item in Project.runtimeLibraries) {
                if (Std.isOfType(item, String)) {
                    app.libs.push(item);
                }
                else {
                    var libName:String = null;
                    var libVersion:String = null;
                    for (key in Reflect.fields(item)) {
                        libName = key;
                        libVersion = Reflect.field(item, key);
                        break;
                    }
                    if (libVersion != null && libVersion.startsWith('git:')) {
                        app.libs.push(libName);
                    }
                    else {
                        app.libs.push(item);
                    }
                }
            }

            var genPath = Path.join([context.cwd, 'gen']);
            if (FileSystem.exists(genPath) && FileSystem.isDirectory(genPath)) {
                var paths:Array<String> = app.paths;
                paths.push('gen');
            }

            if (app.icon == null) {
                app.icon = 'resources/AppIcon.png';
            }
            if (app.iconFlat == null) {
                app.iconFlat = 'resources/AppIcon-flat.png';
            }
            if (app.screen == null) app.screen = {};
            if (app.screen.width == null) {
                app.screen.width = 320;
                app.screen.height = 568;
            }
            if (app.screen.orientation == null) {
                if (app.screen.width > app.screen.height) {
                    app.screen.orientation = 'landscape';
                } else {
                    app.screen.orientation = 'portrait';
                }
            }
            app.lowercaseName = app.name.toLowerCase();

            if (Reflect.hasField(app, 'package')) {
                app.packagePath = (''+Reflect.field(app, 'package')).replace('.', '/');
            }

            // Defines (after evaluating conditions)
            if (app.defines != null) {
                for (key in Reflect.fields(app.defines)) {
                    if (!defines.exists(key)) {
                        var val = Reflect.field(app.defines, key);
                        defines.set(key, val == true ? '' : '' + val);
                    }
                }
            }
            app.defines = {};
            for (key in defines.keys()) {
                var val = defines.get(key);
                Reflect.setField(app.defines, key, val == null || val.trim() == '' ? true : val.trim());
            }
        }
        catch (e:Dynamic) {
            fail("Error when processing app project content: " + e);
        }

        return app;

    }

    public static function loadPluginConfig(input:String, defines:Map<String,String>):Dynamic<Dynamic> {

        var plugin:Dynamic<Dynamic> = null;

        // Parse YAML
        //
        try {
            var parsed = Yaml.parse(input);

            if (parsed.plugin == null) {
                if (parsed.app != null) {
                    fail('This project is not a ceramic plugin project. Is it an app project?');
                } else {
                    fail('This project is not a ceramic plugin project.');
                }
            }

            plugin = parsed.plugin;
        }
        catch (e:Dynamic) {
            fail("Error when parsing project YAML: " + e);
        }

        // Remove runtime key if any
        if (plugin.runtime != null) {
            Reflect.deleteField(plugin, 'runtime');
        }

        try {

            // Update defines from app
            //
            /*var newDefines = new Map<String,String>();
            for (key in defines.keys()) {
                newDefines.set(key, defines.get(key));
            }
            defines = newDefines;*/

            // Defines (before evaluating conditions)
            if (plugin.defines != null) {
                if (Std.isOfType(plugin.defines, Array)) {
                    var pluginDefinesList:Array<Dynamic> = plugin.defines;
                    plugin.defines = {};
                    for (item in pluginDefinesList) {
                        if (Std.isOfType(item, String) || Std.isOfType(item, Bool) || Std.isOfType(item, Float) || Std.isOfType(item, Int)) {
                            Reflect.setField(plugin.defines, item, true);
                        } else {
                            for (key in Reflect.fields(item)) {
                                Reflect.setField(plugin.defines, key, Reflect.field(item, key));
                            }
                        }
                    }
                }
                for (key in Reflect.fields(plugin.defines)) {
                    if (!defines.exists(key)) {
                        var val = Reflect.field(plugin.defines, key);
                        defines.set(key, val == true ? '' : '' + val);
                    }
                }
            }

            // Evaluate conditionals
            evaluateConditionals(plugin, defines, true);

            // Add additional/default config
            if (plugin.libs == null) {
                plugin.libs = [];
            }
            if (plugin.paths == null) {
                plugin.paths = [];
            }

            plugin.lowercaseName = plugin.name.toLowerCase();

            // Defines (after evaluating conditions)
            if (plugin.defines != null) {
                for (key in Reflect.fields(plugin.defines)) {
                    if (!defines.exists(key)) {
                        var val = Reflect.field(plugin.defines, key);
                        defines.set(key, val == true ? '' : '' + val);
                    }
                }
            } else {
                plugin.defines = {};
            }
            for (key in defines.keys()) {
                var val = defines.get(key);
                Reflect.setField(plugin.defines, key, val == null || val.trim() == '' ? true : val.trim());
            }
        }
        catch (e:Dynamic) {
            fail("Error when processing plugin project content: " + e);
        }

        return plugin;

    }

/// Internal

    static function extractEnabledPlugins(data:Dynamic, defines:Map<String,String>):Array<String> {

        var result = [];
        data = Json.parse(Json.stringify(data));
        defines = defines.copy();

        evaluateConditionals(data, defines, true);

        if (data.plugins != null && Std.isOfType(data.plugins, Array)) {
            var pluginList:Array<String> = data.plugins;
            for (pluginName in pluginList) {
                result.push(pluginName);
            }
        }

        return result;

    }

    static function evaluateConditionals(data:Dynamic, defines:Map<String,String>, isRoot:Bool):Void {

        // Parse conditionals
        for (key in Reflect.fields(data)) {
            if (key.startsWith('if ')) {
                // Check if condition evaluates to true with current context
                //
                var parser = new hscript.Parser();
                var condition = parser.parseString('(' + key.substring(3) + ');');

                // Extract identifiers from condition
                var identifiers = extractIdentifiers(key.substring(3));

                // Setup context from defines
                var interp = new hscript.Interp();
                for (defKey in defines.keys()) {
                    var val = defines.get(defKey);
                    interp.variables.set(defKey, val == null || val.trim() == '' ? true : val);
                }

                // Add os-specific defines
                interp.variables.set('os_' + Sys.systemName().toLowerCase(), true);

                // Add missing identifiers used in expression, if any
                for (identifier in identifiers) {
                    if (!interp.variables.exists(identifier)) {
                        interp.variables.set(identifier, false);
                    }
                }

                // Evaluate condition
                var result:Bool = false;
                try {
                    result = interp.execute(condition);
                } catch (e:Dynamic) {
                    warning('Error when evaluating expression \'' + key.substring(3) + '\': ' + e);
                }

                // Merge config if condition is true
                if (result) {
                    mergeConfigs(data, Reflect.field(data, key), defines, isRoot);
                }

                // Remove condition from keys
                Reflect.deleteField(data, key);
            }
        }

    }

    static function mergeConfigs(data:Dynamic, extra:Dynamic, defines:Map<String,String>, isRoot:Bool):Void {

        // Evaluate conditionals of extra (if any)
        evaluateConditionals(extra, defines, false);

        // Merge keys
        for (key in Reflect.fields(extra)) {
            var modifier = null;
            if (key.startsWith('+')) {
                modifier = '+';
                key = key.substring(1);
            }
            else if (key.startsWith('-')) {
                modifier = '-';
                key = key.substring(1);
            }
            var origKey = isRoot || modifier == null ? key : modifier + key;
            var orig:Dynamic = Reflect.field(data, origKey);
            var value:Dynamic = Reflect.field(extra, (modifier != null ? modifier : '') + key);

            // Ensure defines is a map and not an array
            if (key == 'defines') {
                if (Std.isOfType(value, Array)) {
                    var valueList:Array<Dynamic> = value;
                    value = {};
                    for (item in valueList) {
                        if (Std.isOfType(item, String) || Std.isOfType(item, Bool) || Std.isOfType(item, Float) || Std.isOfType(item, Int)) {
                            Reflect.setField(value, item, true);
                        } else {
                            for (key in Reflect.fields(item)) {
                                Reflect.setField(value, key, Reflect.field(item, key));
                            }
                        }
                    }
                }
            }

            if (orig != null && modifier == '+') {
                // Add in array
                if (Std.isOfType(orig, Array) && Std.isOfType(value, Array)) {
                    var list:Array<Dynamic> = cast value;
                    var origList:Array<Dynamic> = cast orig;
                    for (entry in list) {
                        origList.push(entry);
                    }
                }
                // Add in string
                else if (Std.isOfType(orig, String) && Std.isOfType(value, String)) {
                    var str:String = cast value;
                    var origStr:String = cast orig;
                    origStr = origStr.rtrim() + "\n" + str.ltrim();
                    orig = origStr;
                    Reflect.setField(data, origKey, orig);
                }
                // Add in mapping
                else if (!Std.isOfType(orig, String) && !Std.isOfType(orig, Bool) && !Std.isOfType(orig, Int) && !Std.isOfType(orig, Float)) {
                    for (subKey in Reflect.fields(value)) {
                        var subValue = Reflect.field(value, subKey);
                        Reflect.setField(orig, subKey, subValue);
                    }
                }
                else {
                    // We cannot add anything, nothing to do
                }
            }
            else if (orig != null && modifier == '-') {
                // Remove in array
                if (Std.isOfType(orig, Array) && Std.isOfType(value, Array)) {
                    var list:Array<Dynamic> = cast value;
                    var origList:Array<Dynamic> = cast orig;
                    for (entry in list) {
                        origList.remove(entry);
                    }
                }
                // Remove in string
                else if (Std.isOfType(orig, String) && Std.isOfType(value, String)) {
                    var str:String = cast value;
                    var origStr:String = cast orig;
                    origStr = origStr.replace(str, '');
                    orig = origStr;
                    Reflect.setField(data, origKey, orig);
                }
                // Remove in mapping
                else if (!Std.isOfType(orig, String) && !Std.isOfType(orig, Bool) && !Std.isOfType(orig, Int) && !Std.isOfType(orig, Float)) {
                    if (Std.isOfType(value, Array)) {
                        var list:Array<Dynamic> = cast value;
                        for (entry in list) {
                            Reflect.deleteField(orig, entry);
                        }
                    } else {
                        for (subKey in Reflect.fields(value)) {
                            Reflect.deleteField(orig, subKey);
                        }
                    }
                }
                else {
                    // We cannot remove anything, nothing to do
                }
            }
            else {
                // Replace
                Reflect.setField(data, origKey, value);
            }

        }

    }

    static function extractIdentifiers(input:String):Array<String> {

        var identifiers:Map<String,Bool> = new Map();
        var i = 0;
        var len = input.length;
        var cleaned = '';

        while (i < len) {
            var c = input.charAt(i);
            if (RE_ALNUM_CHAR.match(c)) {
                cleaned += c;
            }
            else if (!cleaned.endsWith(' ')) {
                cleaned += ' ';
            }
            i++;
        }

        for (part in cleaned.split(' ')) {
            if (RE_IDENTIFIER.match(part)) {
                identifiers.set(part, true);
            }
        }

        var result = [];
        for (key in identifiers.keys()) {
            result.push(key);
        }
        return result;

    }

}

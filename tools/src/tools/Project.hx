package tools;

import npm.Yaml;
import tools.Helpers.*;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

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

class Project {

/// Properties

    public var app:Dynamic<Dynamic>;

    public var plugin:Dynamic<Dynamic>;

/// Lifecycle

    public function new():Void {

    } //new

    public function loadAppFile(path:String):Void {

        if (!FileSystem.exists(path)) {
            fail('There is no app project file at path: $path');
        }

        if (FileSystem.isDirectory(path)) {
            fail('A directory is not a valid app project path at: $path');
        }

        var data:String = null;
        try {
            data = File.getContent(path);
        }
        catch (e:Dynamic) {
            fail('Unable to read project at path $path: $e');
        }

        app = ProjectLoader.loadAppConfig(data, context.defines);

        // Add path
        app.path = Path.isAbsolute(path) ? path : Path.normalize(Path.join([context.cwd, path]));

        // Let tools plugins extend app config
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

        if (app.hxml == null) app.hxml = '';

    } //loadAppFile

    public function loadPluginFile(path:String):Void {

        if (!FileSystem.exists(path)) {
            fail('There is no plugin project file at path: $path');
        }

        if (FileSystem.isDirectory(path)) {
            fail('A directory is not a valid plugin project path at: $path');
        }

        var data:String = null;
        try {
            data = File.getContent(path);
        }
        catch (e:Dynamic) {
            fail('Unable to read project at path $path: $e');
        }

        plugin = ProjectLoader.loadPluginConfig(data, context.defines);

        // Add path
        plugin.path = Path.isAbsolute(path) ? path : Path.normalize(Path.join([context.cwd, path]));

    } //loadPluginFile

/// Utilities

} //Project

/** Parsing/loading code to read ceramic project format. */
class ProjectLoader {

    public static function loadAppConfig(input:String, defines:Map<String,String>):Dynamic<Dynamic> {

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
            var newDefines = new Map<String,String>();
            for (key in defines.keys()) {
                newDefines.set(key, defines.get(key));
            }
            defines = newDefines;

            // Defines (before evaluating conditions)
            if (app.defines != null) {
                for (key in Reflect.fields(app.defines)) {
                    if (!defines.exists(key)) {
                        defines.set(key, Reflect.field(app.defines, key));
                    }
                }
            }
            else {
                app.defines = {};
            }

            // Evaluate conditionals
            evaluateConditionals(app, defines);

            // Add additional/default config
            if (app.libs == null) {
                app.libs = [];
            }
            if (app.paths == null) {
                app.paths = [];
            }

            // Add required libs
            app.libs.push({
                unifill: '0.4.1'
            });

            if (app.paths == null) {
                app.paths = [];
            }
            if (app.icon == null) {
                app.icon = 'resources/AppIcon.png';
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
                        defines.set(key, Reflect.field(app.defines, key));
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

    } //loadAppConfig

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

        try {
            
            // Update defines from app
            //
            var newDefines = new Map<String,String>();
            for (key in defines.keys()) {
                newDefines.set(key, defines.get(key));
            }
            defines = newDefines;
            // Defines (before evaluating conditions)
            if (plugin.defines != null) {
                for (key in Reflect.fields(plugin.defines)) {
                    if (!defines.exists(key)) {
                        defines.set(key, Reflect.field(plugin.defines, key));
                    }
                }
            }

            // Evaluate conditionals
            evaluateConditionals(plugin, defines);

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
                        defines.set(key, Reflect.field(plugin.defines, key));
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

    } //loadPluginConfig

/// Internal

    static function evaluateConditionals(app:Dynamic, defines:Map<String,String>):Void {

        // Parse conditionals
        for (key in Reflect.fields(app)) {
            if (key.startsWith('if ')) {
                // Check if condition evaluates to true with current context
                //
                var parser = new hscript.Parser();
                var condition = parser.parseString('(' + key.substring(3) + ');');

                // Setup context from defines
                var interp = new hscript.Interp();
                for (defKey in defines.keys()) {
                    var val = defines.get(defKey);
                    interp.variables.set(defKey, val == null || val.trim() == '' ? true : val);
                }

                // Evaluate condition
                var result:Bool = false;
                try {
                    result = interp.execute(condition);
                } catch (e:Dynamic) {}

                // Merge config if condition is true
                if (result) {
                    mergeConfigs(app, Reflect.field(app, key), defines);
                }

                // Remove condition from keys
                Reflect.deleteField(app, key);
            }
        }

    } //evaluateConditionals

    static function mergeConfigs(app:Dynamic, extra:Dynamic, defines:Map<String,String>):Void {

        // Evaluate conditionals of extra (if any)
        evaluateConditionals(extra, defines);

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
            var orig = Reflect.field(app, key);
            var value = Reflect.field(extra, (modifier != null ? modifier : '') + key);

            if (orig != null && modifier == '+') {
                // Add in array
                if (Std.is(orig, Array) && Std.is(value, Array)) {
                    var list:Array<Dynamic> = cast value;
                    var origList:Array<Dynamic> = cast orig;
                    for (entry in list) {
                        origList.push(entry);
                    }
                }
                // Add in string
                else if (Std.is(orig, String) && Std.is(value, String)) {
                    var str:String = cast value;
                    var origStr:String = cast orig;
                    origStr = origStr.rtrim() + "\n" + str.ltrim();
                    orig = origStr;
                    Reflect.setField(app, key, orig);
                }
                // Add in mapping
                else if (!Std.is(orig, String) && !Std.is(orig, Bool) && !Std.is(orig, Int) && !Std.is(orig, Float)) {
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
                if (Std.is(orig, Array) && Std.is(value, Array)) {
                    var list:Array<Dynamic> = cast value;
                    var origList:Array<Dynamic> = cast orig;
                    for (entry in list) {
                        origList.remove(entry);
                    }
                }
                // Remove in string
                else if (Std.is(orig, String) && Std.is(value, String)) {
                    var str:String = cast value;
                    var origStr:String = cast orig;
                    origStr = origStr.replace(str, '');
                    orig = origStr;
                    Reflect.setField(app, key, orig);
                }
                // Remove in mapping
                else if (!Std.is(orig, String) && !Std.is(orig, Bool) && !Std.is(orig, Int) && !Std.is(orig, Float)) {
                    if (Std.is(value, Array)) {
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
                Reflect.setField(app, key, value);
            }

        }

    } //mergeConfigs

} //Parser

package tools;

import npm.Yaml;
import tools.Tools.*;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Project {

/// Properties

    public var app:Dynamic<Dynamic>;

/// Lifecycle

    public function new():Void {

    } //new

    public function loadAppFile(path:String):Void {

        if (!FileSystem.exists(path)) {
            fail('There is no project file at path: $path');
        }

        if (FileSystem.isDirectory(path)) {
            fail('A directory is not a valid project path at: $path');
        }

        var data:String = null;
        try {
            data = File.getContent(path);
        }
        catch (e:Dynamic) {
            fail('Unable to read project at path $path: $e');
        }

        app = ProjectLoader.loadAppConfig(data, settings.defines);

    } //loadFile

/// Utilities

} //Project

/** Parsing/loading code to read ceramic project format. */
class ProjectLoader {

    public static function loadAppConfig(input:String, defines:Map<String,String>):Dynamic<Dynamic> {

        var app:Dynamic<Dynamic> = null;

        // Parse YAML
        //
        try {
            app = Yaml.parse(input).app;
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

            // Evaluate conditionals
            evaluateConditionals(app, defines);

            // Add additional/default config
            if (app.libs == null) {
                app.libs = [];
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
            fail("Error when processing project content: " + e);
        }

        return app;

    } //loadAppConfig

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
                key = key.substring(1);
            }
            var orig = Reflect.field(app, key);
            var value = Reflect.field(extra, modifier + key);

            if (orig != null && modifier == '+') {
                // Add in array
                if (Std.is(orig, Array) && Std.is(value, Array)) {
                    var list:Array<Dynamic> = cast value;
                    var origList:Array<Dynamic> = cast orig;
                    for (entry in list) {
                        origList.push(entry);
                    }
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

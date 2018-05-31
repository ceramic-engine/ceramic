package tools;

import tools.Context;
import tools.Helpers;
import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;

@:keep
class ToolsPlugin {

    static function main():Void {
        
        var module:Dynamic = js.Node.module;
        module.exports = new ToolsPlugin();

    } //main

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

    } //init

    public function extendProject(project:Project):Void {

        var app = project.app;

        app.paths.push(Path.join([context.plugins.get('Http').path, 'runtime/src']));

        if (context.backend != null) {
            var availableTargets = context.backend.getBuildTargets();
            var target = getTargetName(context.args, availableTargets);
            var backend = context.backend.name;

            switch [backend, target] {
                case [_, 'ios' | 'android' | 'windows' | 'mac' | 'linux']:
                    // Use akifox HTTP
                    app.libs.push({ 'akifox-asynchttp': '0.4.7' });
                    app.defines.akifox_asynchttp = '0.4.7';
                default:
            }
        }

    } //extendProject

} //ToolsPlugin

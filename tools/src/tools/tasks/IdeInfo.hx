package tools.tasks;

import tools.Helpers.*;
import tools.Ide;
import haxe.io.Path;
import haxe.Json;

using StringTools;

class IdeInfo extends tools.Task {

    override public function info(cwd:String):String {

        return "Print project information for IDE.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var tasks:Array<IdeInfoTaskItem> = [];
        var variants:Array<IdeInfoVariantItem> = [];

        // Build config
        //
        variants.push({
            name: 'Debug',
            args: ['--debug'],
            group: 'build',
            role: 'build-preset',
            select: {
                args: ['--debug']
            }
        });
        variants.push({
            name: 'Release',
            args: [],
            group: 'build',
            role: 'build-preset'
        });
        variants.push({
            name: 'Distribution',
            args: ['--variant', 'distribution'],
            group: 'build',
            role: 'build-preset',
            select: {
                args: ['--variant', 'distribution']
            }
        });

        // Build params
        //
        variants.push({
            name: 'No skip',
            args: ['--no-skip'],
            group: 'build'
        });

        // Let plugins extend the list
        for (plugin in context.plugins) {
            if (plugin.extendIdeInfo != null) {
                plugin.extendIdeInfo(tasks, variants);
            }
        }

        print(Json.stringify({
            ide: {
                tasks: tasks,
                variants: variants
            }
        }, null, '    '));

    } //run

} //IdeInfo

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

        /*
        variants.push({
            name: 'Distribution',
            args: ['--variant', 'distribution'],
            group: 'build',
            role: 'build-preset',
            select: {
                args: ['--variant', 'distribution']
            }
        });
        */

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

        // Let project extend the list
        try {
            if (project.app.ide != null) {
                var projectTasks:Array<IdeInfoTaskItem> = project.app.ide.tasks;
                var projectVariants:Array<IdeInfoVariantItem> = project.app.ide.variants;

                if (projectTasks != null) {
                    for (item in projectTasks) {
                        if (item == null || Std.is(item, Bool) || Std.is(item, Array) || Std.is(item, Int) || Std.is(item, Float)) {
                            fail('Invalid task item: $item');
                        }
                        if (item.name == null || !Std.is(item.name, String) || ('' + item.name).trim() == '') {
                            fail('Invalid task name in ceramic.yml: ${item.name}');
                        }
                        var itemName = ('' + item.name).trim();
                        if (item.command == null || !Std.is(item.name, String) || ('' + item.name).trim() == '') {
                            fail('Invalid task command in ceramic.yml: ${item.command}');
                        }
                        var itemCommand = ('' + item.command).trim();
                        if (item.args != null && !Std.is(item.args, Array)) {
                            fail('Invalid task args in ceramic.yml: ${item.args}');
                        }
                        var itemArgs:Array<String> = [];
                        if (item.args != null) {
                            var rawItemArgs:Array<Dynamic> = item.args;
                            if (rawItemArgs.length > 0) {
                                for (rawArg in rawItemArgs) {
                                    itemArgs.push('' + rawArg);
                                }
                            }
                        }
                        if (item.groups != null && !Std.is(item.groups, Array)) {
                            fail('Invalid task groups in ceramic.yml: ${item.groups}');
                        }
                        var itemGroups:Array<String> = [];
                        if (item.groups != null) {
                            var rawItemGroups:Array<Dynamic> = item.groups;
                            if (rawItemGroups.length > 0) {
                                for (rawGroup in rawItemGroups) {
                                    var group = ('' + rawGroup).trim();
                                    if (group != '') {
                                        if (itemGroups.indexOf(group) == -1) {
                                            itemGroups.push(group);
                                        }
                                    }
                                }
                            }
                        }
                        if (Reflect.hasField(item, 'group') && Std.is(Reflect.field(item, 'group'), String)) {
                            var group:String = ('' + Reflect.field(item, 'group')).trim();
                            if (group != '') {
                                if (itemGroups.indexOf(group) == -1) {
                                    itemGroups.push(group);
                                }
                            }
                        }
                        var itemSelect:IdeInfoTaskSelectItem = null;
                        if (item.select != null) {
                            if (Std.is(item.select, Bool) || Std.is(item.select, Array) || Std.is(item.select, Int) || Std.is(item.select, Float)) {
                                fail('Invalid task item select: ${item.select}');
                            }
                            var selectCommand = ('' + item.select.command).trim();
                            if (item.select.args != null && !Std.is(item.select.args, Array)) {
                                fail('Invalid task select args in ceramic.yml: ${item.select.args}');
                            }
                            var selectArgs:Array<String> = [];
                            if (item.select.args != null) {
                                var rawSelectArgs:Array<Dynamic> = item.select.args;
                                if (rawSelectArgs.length > 0) {
                                    for (rawArg in rawSelectArgs) {
                                        selectArgs.push('' + rawArg);
                                    }
                                }
                            }
                            itemSelect = {
                                command: selectCommand,
                                args: selectArgs
                            };
                        }
                        tasks.push({
                            name: itemName,
                            command: itemCommand,
                            args: itemArgs,
                            groups: itemGroups,
                            select: itemSelect
                        });
                    }
                } //projectTasks
                
                if (projectVariants != null) {
                    for (item in projectVariants) {
                        if (item == null || Std.is(item, Bool) || Std.is(item, Array) || Std.is(item, Int) || Std.is(item, Float)) {
                            fail('Invalid variant item: $item');
                        }
                        if (item.name == null || !Std.is(item.name, String) || ('' + item.name).trim() == '') {
                            fail('Invalid variant name in ceramic.yml: ${item.name}');
                        }
                        var itemName = ('' + item.name).trim();
                        if (item.args != null && !Std.is(item.args, Array)) {
                            fail('Invalid variant args in ceramic.yml: ${item.args}');
                        }
                        var itemArgs:Array<String> = [];
                        if (item.args != null) {
                            var rawItemArgs:Array<Dynamic> = item.args;
                            if (rawItemArgs.length > 0) {
                                for (rawArg in rawItemArgs) {
                                    itemArgs.push('' + rawArg);
                                }
                            }
                        }
                        var itemGroup:String = null;
                        if (item.group != null && Std.is(item.group, String)) {
                            var group:String = ('' + item.group).trim();
                            if (group != '') {
                                itemGroup = group;
                            }
                        }
                        var itemSelect:IdeInfoVariantSelectItem = null;
                        if (item.select != null) {
                            if (Std.is(item.select, Bool) || Std.is(item.select, Array) || Std.is(item.select, Int) || Std.is(item.select, Float)) {
                                fail('Invalid variant item select: ${item.select}');
                            }
                            if (item.select.args != null && !Std.is(item.select.args, Array)) {
                                fail('Invalid variant select args in ceramic.yml: ${item.select.args}');
                            }
                            var selectArgs:Array<String> = [];
                            if (item.select.args != null) {
                                var rawSelectArgs:Array<Dynamic> = item.select.args;
                                if (rawSelectArgs.length > 0) {
                                    for (rawArg in rawSelectArgs) {
                                        selectArgs.push('' + rawArg);
                                    }
                                }
                            }
                            itemSelect = {
                                args: selectArgs
                            };
                        }
                        variants.push({
                            name: itemName,
                            args: itemArgs,
                            group: itemGroup,
                            select: itemSelect
                        });
                    }
                } //projectVariants
            }
        }
        catch (e:Dynamic) {
            // Something went wrong
            fail('Invalid task list in ceramic.yml: $e');
        }

        print(Json.stringify({
            ide: {
                tasks: tasks,
                variants: variants
            }
        }, null, '    '));

    } //run

} //IdeInfo

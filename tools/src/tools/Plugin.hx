package tools;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
#end

class Plugin {

    macro public static function defaults():Expr {

        return macro $v{pluginData};

    }

    macro public static function constructs():Expr {

        var result = new StringBuf();

        result.add('{');

        var first = true;
        for (item in pluginData) {

            if (item.plugin.tools != null) {

                if (!first) {
                    result.add(', ');
                }
                first = false;
                result.add('"' + item.plugin.id + '": new ' + item.plugin.tools + '()');

            }

        }

        result.add('}');

        return Context.parse(result.toString(), Context.currentPos());

    }

    macro public static function plugin(id:ExprOf<String>):Expr {

        for (item in pluginData) {
            if (item.id == id) {
                return macro $v{item};
            }
        }

        return macro null;

    }

#if macro

    static var pluginData:Array<Dynamic> = [];

    public static function addDefaultPlugins():Void {

        var pluginsPaths = Path.normalize(Path.join([Sys.getCwd(), '../plugins']));

        var pluginIds = [];
        for (dir in FileSystem.readDirectory(pluginsPaths)) {
            final pluginPath = Path.join([pluginsPaths, dir]);
            final pluginYmlPath = Path.join([pluginPath, 'ceramic.yml']);
            final pluginBaseName = Path.withoutDirectory(pluginPath);
            if (FileSystem.exists(pluginYmlPath) && !FileSystem.isDirectory(pluginYmlPath)) {
                final pluginYml:Dynamic = Yaml.parse(File.getContent(pluginYmlPath));
                pluginIds.push(pluginBaseName);
                pluginYml.plugin.id = pluginBaseName;
                pluginYml.plugin.path = pluginPath;
                pluginData.push(pluginYml);

                final pluginToolsSrcPath = Path.join([pluginPath, 'tools/src']);
                final pluginToolsSrcPathBase = Path.join([pluginBaseName, 'tools/src']);
                #if debug_plugins
                Sys.println('* ' + pluginBaseName + ' (' + pluginYml.plugin.name + ')');
                #end
                if (FileSystem.exists(pluginToolsSrcPath) && FileSystem.isDirectory(pluginToolsSrcPath)) {
                    #if debug_plugins
                    Sys.println('  -cp ../plugins/' + pluginToolsSrcPathBase + '');
                    #end
                    Compiler.addClassPath('../plugins/' + pluginToolsSrcPathBase);
                }
                else {
                    #if debug_plugins
                    Sys.println('  .');
                    #end
                }
                #if debug_plugins
                Sys.println('');
                #end
            }
        }

        Sys.println('plugins: ' + pluginIds.join(', '));

    }

#end

}

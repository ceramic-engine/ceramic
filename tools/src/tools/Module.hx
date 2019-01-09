package tools;

import haxe.io.Path;
import tools.Helpers.*;

using StringTools;

class Module {

    public static function patchHxml(cwd:String, project:Project, hxml:String, moduleName:String):String {

        var prevHxml = hxml.split("\n");
        var newHxml = [];
        var srcPath = Path.normalize(Path.join([cwd, 'src']));

        var didInsertCpSrc = false;

        for (line in prevHxml) {
            line = line.trim();

            if (line.startsWith('-cp ')) {
                var path = Path.normalize(line.substring(4).ltrim());
                if (path.startsWith(srcPath + '/') || path == srcPath) {
                    if (!didInsertCpSrc) {
                        if (moduleName == null || moduleName == '') {
                            // No module targeted, link whole src path
                            newHxml.push('-cp ' + srcPath);
                        }
                        else {
                            // Decompose -cp to only target required modules
                            var modulePath = resolvePath(cwd, project, moduleName);
                            var dependencies = resolveDependencies(project, moduleName);
                            var dependants = resolveDependants(project, moduleName);

                            newHxml.push('-cp ' + modulePath);
                            for (dep in dependencies) {
                                var depPath = resolvePath(cwd, project, dep);
                                newHxml.push('-cp ' + depPath);
                            }
                        }
                        didInsertCpSrc = true;
                    }
                    continue;
                }
            }

            newHxml.push(line);
        }

        return newHxml.join("\n");

    } //patchHxml

    public static function resolvePath(cwd:String, project:Project, moduleName:String):String {

        if (project.app.modules == null) fail('ceramic.yml need a modules: key');

        var info = Reflect.field(project.app.modules, moduleName);
        if (info == null) {
            fail('Missing module info for: $moduleName in ceramic.yml');
        }
        if (info.pack == null) {
            fail('Missing pack in module info for: $moduleName in ceramic.yml');
        }

        var pack:String = info.pack;
        var path = Path.join([cwd, 'src', pack.replace('.', '/')]);

        return path;

    } //resolvePath

    public static function resolvePack(cwd:String, project:Project, moduleName:String):String {

        if (project.app.modules == null) fail('ceramic.yml need a modules: key');

        var info = Reflect.field(project.app.modules, moduleName);
        if (info == null) {
            fail('Missing module info for: $moduleName in ceramic.yml');
        }
        if (info.pack == null) {
            fail('Missing pack in module info for: $moduleName in ceramic.yml');
        }

        var pack:String = info.pack;
        return pack;

    } //resolvePack

    public static function resolveDependencies(project:Project, moduleName:String):Array<String> {

        if (project.app.modules == null) fail('ceramic.yml need a modules: key');

        var info = Reflect.field(project.app.modules, moduleName);
        if (info == null) {
            fail('Missing module info for: $moduleName in ceramic.yml');
        }

        var uses:Array<String> = info.uses;
        if (uses == null) return [];
        return uses;

    } //resolveDependencies

    public static function resolveDependants(project:Project, moduleName:String):Array<String> {

        return [];

    } //resolveDependants

} //Module

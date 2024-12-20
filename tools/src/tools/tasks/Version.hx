package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import tools.Helpers.*;

using StringTools;

class Version extends tools.Task {

    override public function info(cwd:String):String {

        return "Print ceramic tools version.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        if (extractArgFlag(args, 'base')) {
            var baseVersion = context.ceramicVersion.split('-')[0];
            print('' + baseVersion);
            return;
        }

        if (extractArgFlag(args, 'short')) {
            print('' + context.ceramicVersion);
            return;
        }

        var checkTag = extractArgValue(args, 'check-tag');
        if (checkTag != null) {
            var expectedTag = 'v' + context.ceramicVersion.split('-')[0];
            var sanitizedTag = checkTag;
            sanitizedTag = ~/[a-zA-Z_-]+$/.replace(sanitizedTag, '');
            if (sanitizedTag != expectedTag) {
                fail('Tag $checkTag doesn\'t match current version: ' + context.ceramicVersion);
            }
            else {
                success('Tag $checkTag is matching current version');
            }
        }

        var toolsPath = context.ceramicToolsPath;
        var homedir:String = homedir();

        // Git version?
        var hash:String = null;
        var date:String = null;
        if (commandExists('git')) {
            hash = command('git', ['rev-parse', '--short', 'HEAD'], { cwd: toolsPath, mute: true }).stdout.trim();
            if (hash != null && hash != '') {
                date = command('git', ['show', '-s', '--format=%ci', hash], { cwd: toolsPath, mute: true }).stdout.trim();
            }
        }

        if (toolsPath.startsWith(homedir)) {
            toolsPath = Path.join(['~', toolsPath.substring(homedir.length)]);
        }

        if (context.isEmbeddedInElectron && toolsPath.endsWith('/Contents/Resources/app/node_modules/ceramic-tools')) {
            toolsPath = toolsPath.substring(0, toolsPath.length - '/Contents/Resources/app/node_modules/ceramic-tools'.length);
        }

        print(context.ceramicVersion + ' (' + toolsPath + ')' + (date != null ? ' $date' : ''));

    }

}

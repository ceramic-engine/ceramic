package tools.tasks;

import tools.Helpers.*;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

using tools.Colors;
using StringTools;

class Help extends tools.Task {

    override public function info(cwd:String):String {

        return "Display help/manual.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var lines = [];
        var tab = '  ';

        // Compute tools version
        var version = 'v' + js.Node.require(Path.join([context.ceramicToolsPath, '../package.json'])).version;
        var versionPath = Path.join([js.Node.__dirname, 'version']);
        if (FileSystem.exists(versionPath)) {
            version = File.getContent(versionPath);
        }

        function b(str:String) {
            return context.colors ? str.bold() : str;
        }

        function r(str:String) {
            return context.colors ? str.reset() : str;
        }

        function i(str:String) {
            return context.colors ? str.italic() : str;
        }

        function g(str:String) {
            return context.colors ? str.gray() : str;
        }

        function u(str:String) {
            return context.colors ? str.underline() : str;
        }

        function bg(str:String) {
            return context.colors ? str.green().bold() : str;
        }

        function green(str:String) {
            return context.colors ? str.green() : str;
        }

        function len(str:String, n:Int) {
            var res = str;
            while (res.length < n) {
                res += ' ';
            }
            return res;
        }

        /* Prints:
                                                       _|
  _|_|_|    _|_|    _|  _|_|   _|_|_|  _|_|_|  _|_|          _|_|_|
_|        _|_|_|_|  _|_|     _|    _|  _|    _|    _|  _|  _|
_|        _|        _|       _|    _|  _|    _|    _|  _|  _|
  _|_|_|    _|_|_|  _|         _|_|_|  _|    _|    _|  _|    _|_|_|

        */
        lines.push('                                              
                                                         '+bg('_|')+'            
    '+bg('_|_|_|')+'    '+bg('_|_|')+'    '+bg('_|')+'  '+bg('_|_|')+'   '+bg('_|_|_|')+'  '+bg('_|_|_|')+'  '+bg('_|_|')+'          '+bg('_|_|_|')+'  
  '+bg('_|')+'        '+bg('_|_|_|_|')+'  '+bg('_|_|')+'     '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'    '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'  '+bg('_|')+'        
  '+bg('_|')+'        '+bg('_|')+'        '+bg('_|')+'       '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'    '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'  '+bg('_|')+'        
    '+bg('_|_|_|')+'    '+bg('_|_|_|')+'  '+bg('_|')+'         '+bg('_|_|_|')+'  '+bg('_|')+'    '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'    '+bg('_|_|_|'));
        
        var logo = lines[lines.length-1];
        var logoLines = logo.replace("\r","").split("\n");
        logoLines[1] += ' ' + green(version);
        lines[lines.length-1] = logoLines.join("\n");

        lines.push("\n");

        lines.push(tab + b('USAGE'));
        lines.push(tab + r('ceramic ') + u('command') + ' '+g('[')+'--arg'+g(',')+' --arg value'+g(', \u2026]'));
        lines.push('');

        lines.push(tab + b('COMMANDS'));

        var allTasks = new Map<String,tools.Task>();

        for (key in context.tasks.keys()) {
            allTasks.set(key, context.tasks.get(key));
        }

        var maxTaskLen = 0;
        for (key in allTasks.keys()) {
            maxTaskLen = cast Math.max(maxTaskLen, key.length);
        }
        
        var i = 0;
        for (key in allTasks.keys()) {
            var task:tools.Task = allTasks.get(key);

            var prevBackend = context.backend;
            context.backend = task.backend;
            var prevPlugin = context.plugin;
            context.plugin = task.plugin;

            if (i == 0) {
                lines.push(tab + r(len(key, maxTaskLen)) + '    ' + g(task.info(cwd)));
            } else {
                lines.push(tab + len(key, maxTaskLen) + '    ' + g(task.info(cwd)));
            }

            context.backend = prevBackend;
            context.plugin = prevPlugin;

            i++;
        }

        print(lines.join("\n") + "\n");

    } //run

} //Help

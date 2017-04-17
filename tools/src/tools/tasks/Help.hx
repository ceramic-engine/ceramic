package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import haxe.Json;

using npm.Colors;
using StringTools;

class Help extends tools.Task {

    override public function info(cwd:String):String {

        return "Display help/manual.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var lines = [];
        var tab = '  ';

        function b(str:String) {
            return settings.colors ? str.bold() : str;
        }

        function i(str:String) {
            return settings.colors ? str.italic() : str;
        }

        function g(str:String) {
            return settings.colors ? str.gray() : str;
        }

        function u(str:String) {
            return settings.colors ? str.underline() : str;
        }

        function bg(str:String) {
            return settings.colors ? str.green() : str;
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
        lines.push(b('                                              
                                                         '+bg('_|')+'            
    '+bg('_|_|_|')+'    '+bg('_|_|')+'    '+bg('_|')+'  '+bg('_|_|')+'   '+bg('_|_|_|')+'  '+bg('_|_|_|')+'  '+bg('_|_|')+'          '+bg('_|_|_|')+'  
  '+bg('_|')+'        '+bg('_|_|_|_|')+'  '+bg('_|_|')+'     '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'    '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'  '+bg('_|')+'        
  '+bg('_|')+'        '+bg('_|')+'        '+bg('_|')+'       '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'    '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'  '+bg('_|')+'        
    '+bg('_|_|_|')+'    '+bg('_|_|_|')+'  '+bg('_|')+'         '+bg('_|_|_|')+'  '+bg('_|')+'    '+bg('_|')+'    '+bg('_|')+'  '+bg('_|')+'    '+bg('_|_|_|')+'                    

                                             '));

        lines.push(tab + b('USAGE'));
        lines.push(tab + 'ceramic ' + u('command') + ' '+g('[')+'--arg'+g(',')+' --arg value'+g(', \u2026]')+' ' + ''+g('[')+'-D someFlag'+g(',')+' -D someFlag=someValue'+g(', \u2026]')+'');
        lines.push('');

        lines.push(tab + b('COMMANDS'));

        var allTasks = new Map<String,tools.Task>();

        for (key in shared.tasks.keys()) {
            allTasks.set(key, shared.tasks.get(key));
        }

        for (backendName in ['luxe']) {

            if (~/^([a-zA-Z0-9_]+)$/.match(backendName) && sys.FileSystem.exists(Path.join([js.Node.__dirname, 'tools-' + backendName + '.js']))) {
                var initTools = js.Node.require('./tools-' + backendName + '.js');
                var tools:tools.Tools = initTools(cwd, ['-D$backendName'].concat(args));

                for (key in tools.tasks.keys()) {
                    allTasks.set(backendName + ' ' + key, tools.tasks.get(key));
                }
            }

        }

        var maxTaskLen = 0;
        for (key in allTasks.keys()) {
            maxTaskLen = cast Math.max(maxTaskLen, key.length);
        }
        
        for (key in allTasks.keys()) {
            var task:tools.Task = allTasks.get(key);

            lines.push(tab + len(key, maxTaskLen) + '    ' + g(task.info(cwd)));
        }

        print(lines.join("\n") + "\n");

    } //run

} //Help

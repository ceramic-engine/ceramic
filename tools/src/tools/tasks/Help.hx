package tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;
using tools.Colors;

class Help extends tools.Task {

    override public function info(cwd:String):String {

        return "Display help/manual.";

    }

    override function run(cwd:String, args:Array<String>):Void {

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
            return context.colors ? str.underline() : '<' + str + '>';
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

        function noltlen(str:String, n:Int) {
            var lenOffset = 0;
            for (i in 0...str.length) {
                var code = str.charCodeAt(i);
                if (code == '<'.code || code == '>'.code)
                    lenOffset--;
            }
            var res = str;
            while (res.length + lenOffset < n) {
                res += ' ';
            }
            return res;
        }

        function ltu(str:String) {
            var result = '';
            var ltText = null;
            for (i in 0...str.length) {
                var c = str.charAt(i);
                if (ltText != null) {
                    if (c == '>') {
                        result += u(ltText);
                        ltText = null;
                    }
                    else {
                        ltText += c;
                    }
                }
                else {
                    if (c == '<') {
                        ltText = '';
                    }
                    else {
                        result += c;
                    }
                }
            }

            return result;
        }

        function nolt(text:String) {
            return text.replace('<', '').replace('>', '');
        }

        var lines = [];
        var tab = '  ';

        var commandName:String = null;
        for (i in 0...args.length) {
            if (i < args.length - 1) {
                if (args[i] == 'help') {
                    commandName = args[i + 1];
                }
                else if (commandName != null) {
                    commandName += ' ' + args[i + 1];
                }
            }
        }

        if (commandName != null) {
            var task = context.task(commandName);
            if (task == null) {
                fail('Unknown command: $commandName');
            }

            var info = task.info(cwd);

            lines.push('');
            lines.push(tab + b('COMMAND'));
            lines.push(tab + 'ceramic ' + commandName + '    ' + g(info));

            var helpData = task.help(cwd);
            if (helpData != null && helpData.length > 0) {
                lines.push('');
                lines.push(tab + b('OPTIONS'));
                var item0Len = 0;
                for (item in helpData) {
                    var noLtText = nolt(item[0]);
                    if (noLtText.length > item0Len)
                        item0Len = noLtText.length;
                }

                for (item in helpData) {
                    lines.push(tab + ltu(noltlen(item[0], item0Len)) + '    ' + g(item[1]));
                }
            }

            print(lines.join("\n") + "\n");

            return;
        }

        var toolsPath = context.ceramicToolsPath;

        // Compute tools version
        var version = 'v' + context.ceramicVersion;
        if (context.isEmbeddedInElectron) version += ' *';

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
        logoLines[1] += '             ' + green(version);
        lines[lines.length-1] = logoLines.join("\n");

        final ellipsis = #if windows '...' #else '\u2026' #end;

        lines.push("\n");

        lines.push(tab + b('USAGE'));
        lines.push(tab + r('ceramic ') + u('command') + ' '+g('[')+'--arg'+g(',')+' --arg value'+g(', $ellipsis]'));
        lines.push('');

        lines.push(tab + b('COMMANDS'));

        var maxTaskLen = 0;
        for (taskEntry in context.tasks) {
            maxTaskLen = cast Math.max(maxTaskLen, taskEntry.key.length);
        }

        var i = 0;
        for (taskEntry in context.tasks) {
            var task:tools.Task = taskEntry.task;
            var key:String = taskEntry.key;

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

        lines.push('');
        lines.push(tab + b('HELP'));
        lines.push(tab + 'ceramic help ' + u('command'));

        print(lines.join("\n") + "\n");

    }

}

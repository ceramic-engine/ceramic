package tools;

import haxe.io.Path;

class Index {

    static function main():Void {

        var args = Sys.args();
        var cwd = Sys.getCwd();

        if (args.length > 0) {

            var first = args[0];

            if (first == 'run') {

                // Run something?

            }
            else if (first == 'help') {

                // Show help

            }
            else {

                // Try module require
                if (~/^([a-zA-Z0-9_]+)$/.match(first) && sys.FileSystem.exists(Path.join([cwd, 'tools-' + first + '.js']))) {
                    js.Node.require('./tools-' + first + '.js');
                }
                else {
                    trace('Invalid argument: $first');
                }
            }

        }

    } //main
    
} //Index

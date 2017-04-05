package tools;

import haxe.io.Path;

class Index {

    static function main():Void {

        // Expose run(cwd, args)
        var module:Dynamic = js.Node.module;
        module.exports = run;
    
    } //main

    static function run(cwd:String, args:Array<String>):Void {

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
                    var tools = js.Node.require('./tools-' + first + '.js');
                    tools();
                }
                else {
                    trace('Invalid argument: $first');
                }
            }

        }

    } //main
    
} //Index

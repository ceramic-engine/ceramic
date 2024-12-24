package tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

class Link extends tools.Task {

    override public function info(cwd:String):String {

        return "Make this ceramic command global.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        if (Sys.systemName() == 'Mac' || Sys.systemName() == 'Linux') {
            command('rm', ['ceramic'], { cwd: '/usr/local/bin', mute: true });
            var script = '#!/bin/bash
${Path.join([context.ceramicToolsPath, 'ceramic'])} "$@"';
            File.saveContent('/usr/local/bin/ceramic', script);
            command('chmod', ['+x', 'ceramic'], { cwd: '/usr/local/bin', mute: true });
        }
        else if (Sys.systemName() == 'Windows') {
            var haxePath = Sys.getEnv('HAXEPATH');
            if (haxePath == null || !FileSystem.exists(haxePath)) {
                fail('Haxe must be installed on this machine in order to link ceramic command.');
            }
            File.saveContent(
                Path.join([haxePath, 'ceramic.cmd']),
                "@echo off\r\n" + Path.join([context.ceramicToolsPath, 'ceramic']) + " %*"
            );
        }

    }

}

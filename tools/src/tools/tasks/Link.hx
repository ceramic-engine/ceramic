package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class Link extends tools.Task {

    override public function info(cwd:String):String {

        return "Make this ceramic command global.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        if (Sys.systemName() == 'Mac') {
            command('rm', ['ceramic'], { cwd: '/usr/local/bin', mute: true });
            if (isElectron()) {
                command('ln', ['-s', Path.join([settings.ceramicPath, 'ceramic-electron']), 'ceramic'], { cwd: '/usr/local/bin' });
            }
            else {
                command('ln', ['-s', Path.join([settings.ceramicPath, 'ceramic']), 'ceramic'], { cwd: '/usr/local/bin' });
            }
        }
        else if (Sys.systemName() == 'Windows') {
            var haxePath = js.Node.process.env['HAXEPATH'];
            if (haxePath == null || !FileSystem.exists(haxePath)) {
                fail('Haxe must be installed on this machine in order to link ceramic command.');
            }
            File.saveContent(
                Path.join([haxePath, 'ceramic.bat']),
                "@echo off\r\n" + Path.join([settings.ceramicPath, isElectron() ? 'ceramic-electron' : 'ceramic']) + " %*"
            );
        }

    } //run

} //Link

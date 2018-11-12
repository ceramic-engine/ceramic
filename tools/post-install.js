#!./node_modules/.bin/node

var spawnSync = require('child_process').spawnSync;
var download = require('download');
var fs = require('fs');
var path = require('path');
var os = require('os');
var decompress = require('decompress');
var rimraf = require('rimraf');

function postInstall() {

    var haxelib = process.platform == 'win32' ? 'haxelib.cmd' : './haxelib';
    var haxe = process.platform == 'win32' ? 'haxe.cmd' : './haxe';

    require('./ceramic-env');

    // Install dependencies
    spawnSync(haxelib, ['install', 'hxnodejs', '4.0.9', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'hxcpp', '4.0.4', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'bind', '0.4.1', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'unifill', '0.4.1', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'spine-hx', '../git/spine-hx'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'polyline', '../git/polyline'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'build.hxml', '--always'], { stdio: "inherit", cwd: __dirname });
    
    // Build tools
    spawnSync(haxe, ['build.hxml'], { stdio: "inherit", cwd: __dirname });

    console.log("post install");
        
    // Build tools plugins
    var ceramic = process.platform == 'win32' ? 'ceramic.bat' : './ceramic';
    spawnSync(ceramic, ['plugin', 'build', '--tools', '--all'], { stdio: "inherit", cwd: __dirname });

} //installDeps

postInstall();

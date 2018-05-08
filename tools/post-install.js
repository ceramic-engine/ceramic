#!./node_modules/.bin/node

var spawnSync = require('child_process').spawnSync;
var download = require('download');
var fs = require('fs');
var path = require('path');
var os = require('os');
var decompress = require('decompress');
var rimraf = require('rimraf');

function postInstall() {

    require('./ceramic-env');

    // Install dependencies
    spawnSync('./haxelib', ['install', 'hxnodejs', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync('./haxelib', ['install', 'hxcpp', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync('./haxelib', ['install', 'bind', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync('./haxelib', ['install', 'unifill', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync('./haxelib', ['install', 'build.hxml', '--always'], { stdio: "inherit", cwd: __dirname });
    
    // Build tools
    spawnSync('./haxe', ['build.hxml'], { stdio: "inherit", cwd: __dirname });
        
    // Build tools plugins
    var ceramic = process.platform == 'win32' ? 'ceramic.bat' : './ceramic';
    spawnSync(ceramic, ['plugin', 'build', '--tools', '--all'], { stdio: "inherit", cwd: __dirname });

} //installDeps

postInstall();

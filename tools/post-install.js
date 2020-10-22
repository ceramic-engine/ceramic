#!./node_modules/.bin/node

var spawnSync = require('child_process').spawnSync;
var download = require('download');
var fs = require('fs-extra');
var path = require('path');
var os = require('os');
var decompress = require('decompress');
var rimraf = require('rimraf');

function postInstall() {

    var haxelib = process.platform == 'win32' ? 'haxelib.cmd' : './haxelib';
    var haxe = process.platform == 'win32' ? 'haxe.cmd' : './haxe';

    require('./ceramic-env');

    // Install dependencies
    var haxelibRepoPath = path.join(__dirname, '..', '.haxelib');
    if (!fs.existsSync(haxelibRepoPath)) {
        fs.mkdirSync(haxelibRepoPath);
    }
    spawnSync(haxelib, ['dev', 'generate', '../git/generate'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'hotml', '../git/hotml'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'hxcpp', '4.1.15', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'build.hxml', '--always'], { stdio: "inherit", cwd: __dirname });

    // Patch hxcpp toolchain on iOS
    // See: https://github.com/HaxeFoundation/hxcpp/issues/764
    /*var hxcppPath = (''+spawnSync(haxelib, ['path', 'hxcpp']).stdout).split("\n")[0].trim();
    var iphoneToolchainPath = path.join(hxcppPath, 'toolchain/iphoneos-toolchain.xml');
    var iphoneToolchain = '' + fs.readFileSync(iphoneToolchainPath);
    iphoneToolchain = iphoneToolchain.split('<flag value="-O2" unless="debug"/>').join('<flag value="-O1" unless="debug"/>');
    fs.writeFileSync(iphoneToolchainPath, iphoneToolchain);*/

    // Patch haxe std with ceramic's overrides
    /*var haxeStdDir = path.join(__dirname, 'node_modules/haxe/downloads/haxe/std');
    var overrideHaxeStdDir = path.join(__dirname, '../haxe/std');
    fs.copySync(overrideHaxeStdDir, haxeStdDir);*/
    
    // Build tools
    spawnSync(haxe, ['build.hxml'], { stdio: "inherit", cwd: __dirname });

    console.log("post install");
        
    // Build tools plugins
    var ceramic = process.platform == 'win32' ? 'ceramic.cmd' : './ceramic';
    spawnSync(ceramic, ['plugin', 'build', '--tools', '--all'], { stdio: "inherit", cwd: __dirname });

    // Not installing electron runner from here anymore, because it doesn't work :(
    // Run `npm install` directly from `runner/` directory
    //var npm = process.platform == 'win32' ? 'npm.cmd' : '../tools/npm';
    //spawnSync(npm, ['install'], { stdio: "inherit", cwd: __dirname + '/../runner' });

}

postInstall();

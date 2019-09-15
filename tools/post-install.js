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
    spawnSync(haxelib, ['install', 'hxnodejs', '4.0.9', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'hxcpp', '4.0.52', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'bind', '0.4.2', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'format', '3.4.2', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'unifill', '0.4.1', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'akifox-asynchttp', '0.4.7', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'arcade', '../git/arcade'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'spine-hx', '../git/spine-hx'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'polyline', '../git/polyline'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'earcut', '../git/earcut'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'actuate', '../git/actuate'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'generate', '../git/generate'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['dev', 'format-tiled', '../git/format-tiled'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'build.hxml', '--always'], { stdio: "inherit", cwd: __dirname });

    // Patch hxcpp toolchain on iOS
    // See: https://github.com/HaxeFoundation/hxcpp/issues/764
    var hxcppPath = (''+spawnSync(haxelib, ['path', 'hxcpp']).stdout).split("\n")[0].trim();
    var iphoneToolchainPath = path.join(hxcppPath, 'toolchain/iphoneos-toolchain.xml');
    var iphoneToolchain = '' + fs.readFileSync(iphoneToolchainPath);
    iphoneToolchain = iphoneToolchain.split('<flag value="-O2" unless="debug"/>').join('<flag value="-O1" unless="debug"/>');
    fs.writeFileSync(iphoneToolchainPath, iphoneToolchain);

    // Patch haxe std with ceramic's overrides
    var haxeStdDir = path.join(__dirname, 'node_modules/haxe/downloads/haxe/std');
    var overrideHaxeStdDir = path.join(__dirname, '../haxe/std');
    fs.copySync(overrideHaxeStdDir, haxeStdDir);
    
    // Build tools
    spawnSync(haxe, ['build.hxml'], { stdio: "inherit", cwd: __dirname });

    console.log("post install");
        
    // Build tools plugins
    var ceramic = process.platform == 'win32' ? 'ceramic.bat' : './ceramic';
    spawnSync(ceramic, ['plugin', 'build', '--tools', '--all'], { stdio: "inherit", cwd: __dirname });

    // Install electron runner
    var npm = process.platform == 'win32' ? 'npm.cmd' : './npm';
    spawnSync(npm, ['install'], { stdio: "inherit", cwd: __dirname + '/../runner' });

} //installDeps

postInstall();

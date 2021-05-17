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
    spawnSync(haxelib, ['install', 'hxcpp', '4.2.1', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelib, ['install', 'build.hxml', '--always'], { stdio: "inherit", cwd: __dirname });

    // Patch hxcpp android clang toolchain until a newer hxcpp lib is published
    var hxcppPath = (''+spawnSync(haxelib, ['path', 'hxcpp']).stdout).split("\n")[0].trim();
    var androidClangToolchainPath = path.join(hxcppPath, 'toolchain/android-toolchain-clang.xml');
    var androidClangToolchain = '' + fs.readFileSync(androidClangToolchainPath);
    var indexOfOptimFlag = androidClangToolchain.indexOf('<flag value="-O2" unless="debug"/>');
    var indexOfStaticLibcpp = androidClangToolchain.indexOf('="-static-libstdc++" />');
    var indexOfLibAtomic = androidClangToolchain.indexOf('name="-latomic"');
    var indexOfPlatform16 = androidClangToolchain.indexOf('<set name="PLATFORM_NUMBER" value="16" />');
    if (indexOfOptimFlag == -1 || indexOfStaticLibcpp != -1 || indexOfLibAtomic == -1 || indexOfPlatform16 != -1) {
        console.log("Patch hxcpp android-clang toolchain");
        if (indexOfOptimFlag == -1)
            androidClangToolchain = androidClangToolchain.split('<flag value="-fpic"/>').join('<flag value="-fpic"/>\n  <flag value="-O2" unless="debug"/>');
        if (indexOfStaticLibcpp != -1)
            androidClangToolchain = androidClangToolchain.split('="-static-libstdc++" />').join('="-static-libstdc++" if="HXCPP_LIBCPP_STATIC" />');
        if (indexOfLibAtomic == -1)
            androidClangToolchain = androidClangToolchain.split('</linker>').join('  <lib name="-latomic" if="HXCPP_LIB_ATOMIC" />\n</linker>');
        if (indexOfPlatform16 != -1)
            androidClangToolchain = androidClangToolchain.split('<set name="PLATFORM_NUMBER" value="16" />').join('<set name="PLATFORM_NUMBER" value="21" />');
    }

    fs.writeFileSync(androidClangToolchainPath, androidClangToolchain);

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

    console.log("Build tools");
    
    // Build tools
    spawnSync(haxe, ['build.hxml'], { stdio: "inherit", cwd: __dirname });
        
    // Build tools plugins
    var ceramic = process.platform == 'win32' ? 'ceramic.cmd' : './ceramic';
    spawnSync(ceramic, ['plugin', 'build', '--tools', '--all'], { stdio: "inherit", cwd: __dirname });

    // Not installing electron runner from here anymore, because it doesn't work :(
    // Run `npm install` directly from `runner/` directory
    //var npm = process.platform == 'win32' ? 'npm.cmd' : '../tools/npm';
    //spawnSync(npm, ['install'], { stdio: "inherit", cwd: __dirname + '/../runner' });

}

postInstall();

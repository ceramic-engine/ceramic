#!/usr/bin/env node

var spawnSync = require('child_process').spawnSync;
var download = require('download');
var fs = require('fs');
var path = require('path');
var os = require('os');
var decompress = require('decompress');
var rimraf = require('rimraf');

var vendorDir;
var haxeBin;
var haxelibBin;
var nekoBin
if (process.platform == 'darwin') {
    vendorDir = path.join(__dirname, 'vendor/mac');
    haxeBin = path.join(vendorDir, 'haxe/haxe');
    haxelibBin = path.join(vendorDir, 'haxe/haxelib');
    nekoBin = path.join(vendorDir, 'neko/neko');
}

downloadHaxe();

function downloadHaxe() {

    // Download haxe
    var url;
    if (process.platform == 'darwin') {
        url = 'https://github.com/HaxeFoundation/haxe/releases/download/3.4.2/haxe-3.4.2-osx.tar.gz';
    } else if (process.platform == 'win32') {
        downloadNeko();
        return;
    }
    var archiveRootDirName = 'haxe-3.4.2';
    var archiveName = url.substr(url.lastIndexOf('/') + 1);
    if (!fs.existsSync(haxeBin)) {

        console.log('Download ' + url);
        download(url)
        .then(data => {
            
            // Write tar.gz
            var archivePath = path.join(vendorDir, archiveName);
            fs.writeFileSync(archivePath, data);

            // Extract archive
            decompress(archivePath, process.platform == 'win32' ? path.join(vendorDir, 'haxe') : vendorDir).then(() => {

                fs.unlinkSync(archivePath);
                if (process.platform == 'darwin') {
                    fs.renameSync(path.join(vendorDir, archiveRootDirName), path.join(vendorDir, 'haxe'));
                }

                downloadNeko();

            }, (err) => {
                throw err;
            });

        }, error => {
            throw error;
        });

    }
    else {
        downloadNeko();
    }

} //downloadHaxe

function downloadNeko() {

    // Download neko
    var url;
    if (process.platform == 'darwin') {
        url = 'https://github.com/jeremyfa/precompiled-bins/releases/download/neko/neko-2.1.0-mac.zip';
    } else if (process.platform == 'win32') {
        installDeps();
        return;
    }
    var archiveRootDirName = 'neko-2.1.0-mac';
    var archiveName = url.substr(url.lastIndexOf('/') + 1);
    if (!fs.existsSync(nekoBin)) {

        console.log('Download ' + url);
        download(url)
        .then(data => {
            
            // Write tar.gz
            var archivePath = path.join(vendorDir, archiveName);
            fs.writeFileSync(archivePath, data);

            // Extract archive
            decompress(archivePath, vendorDir).then(() => {

                // Remove mac-specific dir (just in case)
                if (fs.existsSync(path.join(vendorDir, '__MACOSX'))) {
                    rimraf.sync(path.join(vendorDir, '__MACOSX'));
                }

                fs.unlinkSync(archivePath);
                fs.renameSync(path.join(vendorDir, archiveRootDirName), path.join(vendorDir, 'neko'));

                installDeps();

            }, (err) => {
                throw err;
            });

        }, error => {
            throw error;
        });

    }
    else {
        installDeps();
    }

} //downloadNeko

function installDeps() {

    require('./ceramic-env');

    // Setup haxelib repository (if needed)
    var haxelibRepo = (''+spawnSync('haxelib', ['config'], { cwd: __dirname }).stdout).trim();
    if (!fs.existsSync(haxelibRepo)) {
        haxelibRepo = path.join(os.homedir(), '.ceramic/haxelib');
        spawnSync('haxelib', ['setup', haxelibRepo], { stdio: "inherit", cwd: __dirname });
    }

    // Install dependencies
    spawnSync('haxelib', ['install', 'hxcpp', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync('haxelib', ['install', 'tools.hxml', '--always'], { stdio: "inherit", cwd: __dirname });

    // Build tools
    spawnSync('node', ['./build-tools.js'], { stdio: "inherit", cwd: __dirname });

} //installDeps

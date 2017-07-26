#!/usr/bin/env node

var spawnSync = require('child_process').spawnSync;
var download = require('download');
var fs = require('fs');
var path = require('path');
var os = require('os');
var decompress = require('decompress');
var rimraf = require('rimraf');

// TODO windows
var vendorDir;
var haxeBin;
var haxelibBin;
var nodeBin;
var gitBin;
if (process.platform == 'darwin') {
    vendorDir = path.join(__dirname, 'vendor/mac');
    haxeBin = path.join(vendorDir, 'haxe/haxe');
    haxelibBin = path.join(vendorDir, 'haxe/haxelib');
    nodeBin = path.join(vendorDir, 'node/bin/node');
    gitBin = path.join(vendorDir, 'git/bin/git');
} else if (process.platform == 'win32') {
    vendorDir = path.join(__dirname, 'vendor/windows');
    haxeBin = path.join(vendorDir, 'haxe/haxe.exe');
    haxelibBin = path.join(vendorDir, 'haxe/haxelib.exe');
    nodeBin = path.join(vendorDir, 'node/bin/node.exe');
    gitBin = path.join(vendorDir, 'git/bin/git.exe');
}

downloadHaxe();

function downloadHaxe() {

    // Download haxe
    var haxeUrl;
    if (process.platform == 'darwin') {
        haxeUrl = 'https://github.com/HaxeFoundation/haxe/releases/download/3.4.2/haxe-3.4.2-osx.tar.gz';
    } else if (process.platform == 'win32') {
        haxeUrl = 'https://github.com/HaxeFoundation/haxe/releases/download/3.4.2/haxe-3.4.2-win.zip';
    }
    var haxeArchiveRootDirName = 'haxe-3.4.2';
    var haxeArchiveName = haxeUrl.substr(haxeUrl.lastIndexOf('/') + 1);
    if (!fs.existsSync(haxeBin)) {

        console.log('Download ' + haxeUrl);
        download(haxeUrl)
        .then(data => {
            
            // Write tar.gz
            var archivePath = path.join(vendorDir, haxeArchiveName);
            fs.writeFileSync(archivePath, data);

            // Extract archive
            decompress(archivePath, vendorDir).then(() => {

                fs.unlinkSync(archivePath);
                fs.renameSync(path.join(vendorDir, haxeArchiveRootDirName), path.join(vendorDir, 'haxe'));

                downloadNode();

            }, (err) => {
                throw err;
            });

        }, error => {
            throw error;
        });

    }
    else {
        downloadNode();
    }

} //downloadHaxe

function downloadNode() {

    // Download nodejs
    var nodeUrl;
    var nodeArchiveRootDirName;
    if (process.platform == 'darwin') {
        nodeUrl = 'https://nodejs.org/dist/v6.11.1/node-v6.11.1-darwin-x64.tar.gz';
        nodeArchiveRootDirName = 'node-v6.11.1-darwin-x64';
    } else if (process.platform == 'win32') {
        nodeUrl = 'https://nodejs.org/dist/v6.11.1/node-v6.11.1-win-x64.zip';
        nodeArchiveRootDirName = 'node-v6.11.1-win-x64';
    }
    var nodeArchiveName = nodeUrl.substr(nodeUrl.lastIndexOf('/') + 1);
    if (!fs.existsSync(nodeBin)) {

        console.log('Download ' + nodeUrl);
        download(nodeUrl)
        .then(data => {
            
            // Write tar.gz
            var archivePath = path.join(vendorDir, nodeArchiveName);
            fs.writeFileSync(archivePath, data);

            // Extract archive
            decompress(archivePath, vendorDir).then(() => {

                fs.unlinkSync(archivePath);
                fs.renameSync(path.join(vendorDir, nodeArchiveRootDirName), path.join(vendorDir, 'node'));

                downloadGit();

            }, (err) => {
                throw err;
            });

        }, error => {
            throw error;
        });

    }
    else {
        downloadGit();
    }

} //downloadNode

function downloadGit() {

    // Download git
    var gitUrl;
    var gitArchiveRootDirName;
    if (process.platform == 'darwin') {
        gitUrl = 'https://github.com/jeremyfa/precompiled-git/releases/download/v2.9.3/git-v2.9.3-mac.zip';
    } else if (process.platform == 'win32') {
        gitUrl = 'https://github.com/jeremyfa/precompiled-git/releases/download/v2.9.4/git-v2.9.4-win.zip';
    }
    gitArchiveRootDirName = 'git';
    var gitArchiveName = gitUrl.substr(gitUrl.lastIndexOf('/') + 1);
    if (!fs.existsSync(gitBin)) {

        console.log('Download ' + gitUrl);
        download(gitUrl)
        .then(data => {
            
            // Write tar.gz
            var archivePath = path.join(vendorDir, gitArchiveName);
            fs.writeFileSync(archivePath, data);

            // Extract archive
            decompress(archivePath, vendorDir).then(() => {

                fs.unlinkSync(archivePath);

                // Remove mac-specific dir (just in case)
                if (fs.existsSync(path.join(vendorDir, '__MACOSX'))) {
                    rimraf.sync(path.join(vendorDir, '__MACOSX'));
                }

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

} //downloadGit

function installDeps() {

    // Setup haxelib repository (if needed)
    var haxelibRepo = (''+spawnSync(haxelibBin, ['config'], { cwd: __dirname }).stdout).trim();
    if (!fs.existsSync(haxelibRepo)) {
        haxelibRepo = path.join(os.homedir(), '.ceramic/haxelib');
        spawnSync(haxelibBin, ['setup', haxelibRepo], { stdio: "inherit", cwd: __dirname });
    }

    // Install dependencies
    spawnSync(haxelibBin, ['install', 'hxcpp', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelibBin, ['install', 'tools.hxml', '--always'], { stdio: "inherit", cwd: __dirname });

    // Build tools
    spawnSync(nodeBin, ['build-tools.js'], { stdio: "inherit", cwd: __dirname });

} //installDeps

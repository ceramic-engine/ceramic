#!/usr/bin/env node

var spawnSync = require('child_process').spawnSync;
var download = require('download');
var fs = require('fs');
var path = require('path');
var decompress = require('decompress');
var decompressTargz = require('decompress-targz');

// TODO windows
var vendorDir = path.join(__dirname, 'vendor/mac');
var haxeBin = path.join(vendorDir, 'haxe/haxe');
var haxelibBin = path.join(vendorDir, 'haxe/haxelib');
var nodeBin = path.join(vendorDir, 'node/bin/node');

downloadHaxe();

function downloadHaxe() {

    // Download haxe
    var haxeUrl = 'https://github.com/HaxeFoundation/haxe/releases/download/3.4.2/haxe-3.4.2-osx.tar.gz';
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
            decompress(archivePath, vendorDir, {
                plugins: [decompressTargz()]
            }).then(() => {

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
    // TODO windows
    var nodeUrl = 'https://nodejs.org/dist/v6.11.1/node-v6.11.1-darwin-x64.tar.gz';
    var nodeArchiveRootDirName = 'node-v6.11.1-darwin-x64';
    var nodeArchiveName = nodeUrl.substr(nodeUrl.lastIndexOf('/') + 1);
    if (!fs.existsSync(nodeBin)) {

        console.log('Download ' + nodeUrl);
        download(nodeUrl)
        .then(data => {
            
            // Write tar.gz
            var archivePath = path.join(vendorDir, nodeArchiveName);
            fs.writeFileSync(archivePath, data);

            // Extract archive
            decompress(archivePath, vendorDir, {
                plugins: [decompressTargz()]
            }).then(() => {

                fs.unlinkSync(archivePath);
                fs.renameSync(path.join(vendorDir, nodeArchiveRootDirName), path.join(vendorDir, 'node'));

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

} //downloadNode

function installDeps() {

    // Install dependencies
    spawnSync(haxelibBin, ['install', 'hxcpp', '--always'], { stdio: "inherit", cwd: __dirname });
    spawnSync(haxelibBin, ['install', 'tools.hxml', '--always'], { stdio: "inherit", cwd: __dirname });

    // Build tools
    spawnSync(nodeBin, ['build-tools.js'], { stdio: "inherit", cwd: __dirname });

} //installDeps

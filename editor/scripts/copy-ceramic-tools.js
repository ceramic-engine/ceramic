#!/usr/bin/env node

// This script will be executed at preinstall stage, so no third party module is available. We need to get away with default modules

const spawnSync = require('child_process').spawnSync;
const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname, '../../tools');
const dstDir = path.join(__dirname, '../../tools-editor');

function deleteRecursive(dir) {
    if (fs.existsSync(dir)) {
        fs.readdirSync(dir).forEach(function(file, index) {
            var curPath = path.join(dir, file);
            if (fs.lstatSync(curPath).isDirectory()) {
                deleteRecursive(curPath);
            } else {
                fs.unlinkSync(curPath);
            }
        });
        fs.rmdirSync(path);
    }
}

function copyRecursive(src, dest) {
    var exists = fs.existsSync(src);
    var stats = exists && fs.statSync(src);
    var isDirectory = exists && stats.isDirectory();
    if (exists && isDirectory) {
        fs.mkdirSync(dest);
        fs.readdirSync(src).forEach(function(childItemName) {
            copyRecursive(
                path.join(src, childItemName),
                path.join(dest, childItemName)
            );
        });
    } else {
        fs.copyFileSync(src, dest);
    }
}

if (process.platform == 'win32') {
    // Use node implementation on Windows
    if (fs.existsSync(dstDir)) {
        deleteRecursive(dstDir);
    }
    copyRecursive(srcDir, dstDir);
}
else {
    // Use shell on OSX/Linux
    if (fs.existsSync(dstDir)) {
        spawnSync('rm', ['-rf', dstDir], { stdio: 'inherit' });
    }
    spawnSync('cp', ['-R', srcDir, dstDir], { stdio: 'inherit' });
}

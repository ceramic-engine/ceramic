#!/usr/bin/env node

const spawn = require('child_process').spawn;
const path = require('path');
const net = require('net');

var cwd = path.normalize(path.join(__dirname, '..'));

// Start app dev server
console.log('Starting app dev server\u2026');
var appProc = spawn('npm.cmd', ['run', 'app-dev'], { cwd: cwd });

// Check server is running
//
const port = 3000;
const client = new net.Socket();

let startedElectron = false;
const tryConnection = () => client.connect({port: port}, () => {
    client.end();
    if (!startedElectron) {
        startedElectron = true;
        startElectron();
    }
});

tryConnection();

client.on('error', (error) => {
    setTimeout(tryConnection, 1000);
});

var electronProc;
function startElectron() {
    console.log('Starting electron\u2026');
    electronProc = spawn('npm.cmd', ['run', 'electron-dev'], { cwd: cwd, stdio: 'inherit' });
}

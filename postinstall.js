#!/usr/bin/env node

var spawnSync = require('child_process').spawnSync;

// Install dependencies
spawnSync('haxelib', ['install', 'hxcpp', '--always'], { stdio: "inherit", cwd: __dirname });
spawnSync('haxelib', ['install', 'tools.hxml', '--always'], { stdio: "inherit", cwd: __dirname });

// Build tools
spawnSync('node', ['build-tools.js'], { stdio: "inherit", cwd: __dirname });

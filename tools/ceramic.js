#!/usr/bin/env node

var fs = require('fs');
var path = require('path');

// Expose global require
global.rReq = function(module) { return require.main.require(module) };

// Load shared or local ceramic
var ceramic;
var localPath = path.join(process.cwd(), '.ceramic/index.js');
if (fs.existsSync(localPath)) {
    ceramic = require(localPath);
} else {
    ceramic = require('./index.js');
}

// Run ceramic
ceramic(process.cwd(), process.argv.slice(2), __dirname);

#!./node_modules/.bin/node

var fs = require('fs');
var path = require('path');

// Give access to haxe, haxelib, neko commands from ceramic
// Example: on Mac & Linux, you type `$(ceramic haxe) -version` to run haxe command and get haxe version
if (process.argv.length == 3) {
    if (process.argv[2] == 'haxelib') {
        process.stdout.write(path.join(__dirname, 'haxelib') + '\n');
        process.exit(0);
    }
    if (process.argv[2] == 'haxe') {
        process.stdout.write(path.join(__dirname, 'haxe') + '\n');
        process.exit(0);
    }
    if (process.argv[2] == 'neko') {
        process.stdout.write(path.join(__dirname, 'neko') + '\n');
        process.exit(0);
    }
}

// Expose global require
global.rReqOrig = require;
global.rReq = function(module) {
    // Try first to require from ceramic core's node modules
    if (rReqOrig.resolve(module)) {
        return rReqOrig(module);
    }
    // If nothing was resolved, try to require from plugin's node modules (if it is a plugin)
    else {
        return require.main.require(module);
    }
};

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

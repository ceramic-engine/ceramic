#!./node_modules/.bin/node

var fs = require('fs');
var path = require('path');

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

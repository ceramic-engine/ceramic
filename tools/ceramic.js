#!./node_modules/.bin/node

var fs = require('fs');
var path = require('path');

// Look for .ceramic file in cwd or a parent dir
var resolvedCwd = process.cwd();
for (var i = 0; i < process.argv.length - 1; i++) {
    var arg = process.argv[i];
    if (arg == '--cwd') {
        resolvedCwd = process.argv[i + 1];
        if (!path.isAbsolute(resolvedCwd)) {
            resolvedCwd = path.normalize(path.join(process.cwd(), resolvedCwd));
        }
        break;
    }
}

var pathParts = path.normalize(resolvedCwd).split(path.sep);
while (pathParts.length > 0) {
    var ceramicRefFile = path.join(pathParts.join(path.sep), '.ceramic-tools');
    if (fs.existsSync(ceramicRefFile)) {
        var ceramicPath = fs.readFileSync(ceramicRefFile, 'utf8');
        if (!path.isAbsolute(ceramicPath)) {
            ceramicPath = path.join(pathParts.join(path.sep), ceramicPath);
        }
        ceramicPath = path.normalize(ceramicPath);

        if (!fs.existsSync(path.join(ceramicPath, 'ceramic'))) {
            console.error('Invalid ceramic path: ' + ceramicPath);
            process.exit(1);
        }

        if (ceramicPath != __dirname) {
            var args = [];
            if (process.platform != 'win32') {
                args.push(path.join(ceramicPath, 'ceramic'));
            }
            for (var i = 2; i < process.argv.length; i++) {
                var arg = process.argv[i];
                args.push(arg);
            }
    
            var cmd = path.join(ceramicPath, 'node_modules/.bin/node');
            if (process.platform == 'win32') {
                cmd = path.join(ceramicPath, 'ceramic.cmd');
            }
            proc = require('child_process').spawn(
                cmd,
                args,
                {
                    stdio: 'inherit',
                    cwd: process.cwd()
                }
            );
            proc.on('close', function(code) {
                process.exit(code);
            });
            return;
        }
        else {
            break;
        }
    }
    pathParts.pop();
}

// Give access to haxe, haxelib, neko, node, npm commands from ceramic
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
    if (process.argv[2] == 'node') {
        process.stdout.write(path.join(__dirname, 'node') + '\n');
        process.exit(0);
    }
    if (process.argv[2] == 'npm') {
        process.stdout.write(path.join(__dirname, 'npm') + '\n');
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

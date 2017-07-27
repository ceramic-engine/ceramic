#!/usr/bin/env node

require('./ceramic-env');

var glob = require('glob');
var path = require('path');
var fs = require('fs');
var ncp = require('ncp');
var rimraf = require('rimraf');
var spawnSync = require('child_process').spawnSync;


// Configure target
var args = [];
var customPath = null;
if (process.argv.length >= 3) {
    if (fs.existsSync(process.argv[2])) {
        customPath = process.argv[2];
    }
}

// Setup target
var targetToolsArgs = ['-js', 'index.js'];
var targetLuxeToolsArgs = ['-js', 'tools-luxe.js'];

// Target is custom?
if (customPath != null) {
    // Copy node modules
    if (!fs.existsSync(path.join(customPath, '.ceramic'))) {
        fs.mkdirSync(path.join(customPath, '.ceramic'));
    }

    // Change targets
    targetToolsArgs = ['-js', path.join(customPath, '.ceramic/index.js')];
    targetLuxeToolsArgs = ['-js', path.join(customPath, '.ceramic/tools-luxe.js')];
}

// Discover plugins tools
var ceramicPlugins = glob.sync(path.join(__dirname, 'plugins/*/tools/src/tools/*Tools.hx'));
if (customPath != null && fs.existsSync(path.join(customPath, 'plugins'))) {
    ceramicPlugins = glob.sync(path.join(customPath, 'plugins/*/tools/src/tools/*Tools.hx')).concat(ceramicPlugins);
}
var usedNames = [];
for (plugin of ceramicPlugins) {
    var basename = path.basename(plugin);
    var pluginName = path.basename(path.dirname(path.dirname(path.dirname(path.dirname(plugin)))));
    if (usedNames.indexOf(pluginName) != -1) continue;
    usedNames.push(pluginName);
    args.push('-cp');
    args.push(path.dirname(path.dirname(plugin)));
    args.push('tools.' + basename.substr(0, basename.length - 3));
}

// Build tools
spawnSync('haxe', ['tools.hxml'].concat(targetToolsArgs).concat(args), { stdio: "inherit", cwd: __dirname });
spawnSync('haxe', ['tools-luxe.hxml'].concat(targetLuxeToolsArgs).concat(args), { stdio: "inherit", cwd: __dirname });

// Override require (but try not to break source maps)
if (customPath != null) {
    for (file of ['index.js', 'tools-luxe.js']) {
        content = ''+fs.readFileSync(path.join(customPath, '.ceramic/' + file));
        content = content.split("\n");
        var firstLine = content[0];
        content[0] = 'require=m=>rReq(m);';
        while (content[0].length < firstLine.length) {
            content[0] += '/';
        }
        content = content.join("\n");
        fs.writeFileSync(path.join(customPath, '.ceramic/' + file), content);
    }

    // Compute version file
    var version = 'v' + require('./package.json').version + '-local';
    fs.writeFileSync(path.join(customPath, '.ceramic/version'), version);
}

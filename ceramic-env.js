
var path = require('path');
var fs = require('fs');
var spawnSync = require('child_process').spawnSync;

// Mac
if (process.platform == 'darwin') {
    var vendorDir = path.join(__dirname, 'vendor/mac');

    // Expose Haxe/Haxelib
    var haxePath = path.join(vendorDir, 'haxe');
    process.env['PATH'] = haxePath + ':' + process.env['PATH'];

    // Expose Neko
    var nekoPath = path.join(vendorDir, 'neko');
    if (!fs.existsSync('/usr/local/lib/neko')) {
        // Link with local neko, only if not existing already
        spawnSync('ln', ['-s', nekoPath, 'neko'], { cwd: '/usr/local/lib' });
    }
    process.env['PATH'] = nekoPath + ':' + process.env['PATH'];
    process.env['DYLD_LIBRARY_PATH'] = process.env['DYLD_LIBRARY_PATH'] != null ?
        nekoPath + ':' + process.env['DYLD_LIBRARY_PATH'] :
        nekoPath;

}

// TODO windows

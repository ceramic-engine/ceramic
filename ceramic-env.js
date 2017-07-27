
var path = require('path');
var fs = require('fs');
var spawnSync = require('child_process').spawnSync;

// Mac
if (process.platform == 'darwin') {
    var vendorDir = path.join(__dirname, 'vendor/mac');

    // Expose Haxe/Haxelib
    //
    var haxePath = path.join(vendorDir, 'haxe');
    if (!fs.existsSync('/usr/local/bin/haxe')) {
        spawnSync('ln', ['-s', path.join(haxePath, 'haxe'), 'haxe'], { cwd: '/usr/local/bin', stdio: 'inherit' });
    }
    if (!fs.existsSync('/usr/local/bin/haxelib')) spawnSync('ln', ['-s', path.join(haxePath, 'haxelib'), 'haxelib'], { cwd: '/usr/local/bin' });
    if (!fs.existsSync('/usr/local/lib/haxe')) spawnSync('ln', ['-s', haxePath, 'haxe'], { cwd: '/usr/local/lib' });

    // Expose Neko
    //
    var nekoPath = path.join(vendorDir, 'neko');
    if (!fs.existsSync('/usr/local/lib/neko')) spawnSync('ln', ['-s', nekoPath, 'neko'], { cwd: '/usr/local/lib' });
    if (!fs.existsSync('/usr/local/lib/libneko.dylib')) {
        spawnSync('ln', ['-s', '/usr/local/lib/neko/libneko.dylib', 'libneko.dylib'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', '/usr/local/lib/neko/libneko.2.1.0.dylib', 'libneko.2.1.0.dylib'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', '/usr/local/lib/neko/libneko.2.dylib', 'libneko.2.dylib'], { cwd: '/usr/local/lib' });
    }
    if (!fs.existsSync('/usr/local/lib/nekoc')) spawnSync('ln', ['-s', '/usr/local/lib/neko/nekoc', 'nekoc'], { cwd: '/usr/local/lib' });
    if (!fs.existsSync('/usr/local/lib/nekotools')) spawnSync('ln', ['-s', '/usr/local/lib/neko/nekotools', 'nekotools'], { cwd: '/usr/local/lib' });

}

// TODO windows

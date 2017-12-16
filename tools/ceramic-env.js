
var path = require('path');
var fs = require('fs');
var spawnSync = require('child_process').spawnSync;

// This will ensure we can run haxe/haxelib/neko on this machine and that
// tools ceramic uses can also find them. If the current machine already has haxe/haxelib/neko
// installed, they will be used (and no patch will be applied).

// EDIT: for now let's not do anything like this.

// Mac
/*if (process.platform == 'darwin') {
    var vendorDir = path.join(__dirname, 'vendor/mac');

    // Expose Haxe/Haxelib
    //
    var haxePath = path.join(vendorDir, 'haxe');
    if (!fs.existsSync('/usr/local/bin/haxe')) {
        spawnSync('rm', ['haxe'], { cwd: '/usr/local/bin' });
        spawnSync('ln', ['-s', path.join(haxePath, 'haxe'), 'haxe'], { cwd: '/usr/local/bin', stdio: 'inherit' });
    }
    if (!fs.existsSync('/usr/local/bin/haxelib')) {
        spawnSync('rm', ['haxelib'], { cwd: '/usr/local/bin' });
        spawnSync('ln', ['-s', path.join(haxePath, 'haxelib'), 'haxelib'], { cwd: '/usr/local/bin' });
    }
    if (!fs.existsSync('/usr/local/lib/haxe')) {
        spawnSync('rm', ['haxe'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', haxePath, 'haxe'], { cwd: '/usr/local/lib' });
    }

    // Expose Neko
    //
    var nekoPath = path.join(vendorDir, 'neko');
    if (!fs.existsSync('/usr/local/bin/neko')) {
        spawnSync('rm', ['neko'], { cwd: '/usr/local/bin' });
        spawnSync('ln', ['-s', path.join(nekoPath, 'neko'), 'neko'], { cwd: '/usr/local/bin' });
    }
    if (!fs.existsSync('/usr/local/lib/neko')) {
        spawnSync('rm', ['neko'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', nekoPath, 'neko'], { cwd: '/usr/local/lib' });
    }
    if (!fs.existsSync('/usr/local/lib/libneko.dylib')) {
        spawnSync('rm', ['libneko.dylib'], { cwd: '/usr/local/lib' });
        spawnSync('rm', ['libneko.2.1.0.dylib'], { cwd: '/usr/local/lib' });
        spawnSync('rm', ['libneko.2.dylib'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', '/usr/local/lib/neko/libneko.dylib', 'libneko.dylib'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', '/usr/local/lib/neko/libneko.2.1.0.dylib', 'libneko.2.1.0.dylib'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', '/usr/local/lib/neko/libneko.2.dylib', 'libneko.2.dylib'], { cwd: '/usr/local/lib' });
    }
    if (!fs.existsSync('/usr/local/lib/nekoc')) {
        spawnSync('rm', ['nekoc'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', '/usr/local/lib/neko/nekoc', 'nekoc'], { cwd: '/usr/local/lib' });
    }
    if (!fs.existsSync('/usr/local/lib/nekotools')) {
        spawnSync('rm', ['nekotools'], { cwd: '/usr/local/lib' });
        spawnSync('ln', ['-s', '/usr/local/lib/neko/nekotools', 'nekotools'], { cwd: '/usr/local/lib' });
    }

}*/

// Embedded haxe/haxelib/neko is not supported on Windows at the moment.
// The user must install Haxe (wich includes neko as well) with official installer

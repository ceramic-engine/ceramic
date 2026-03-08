package tools.tasks.windows;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class CrossSetup extends tools.Task {

    override public function info(cwd:String):String {
        return "Set up cross-compilation toolchain for building Windows apps from Mac/Linux";
    }

    override function run(cwd:String, args:Array<String>):Void {

        if (Sys.systemName() == 'Windows') {
            print('Cross-compilation setup is not needed on Windows. Use the native MSVC toolchain instead.');
            return;
        }

        // Step 1: Check for LLVM tools
        print('Checking for LLVM tools...');
        var missingTools = new Array<String>();
        for (tool in ['clang-cl', 'lld-link', 'llvm-lib', 'llvm-rc']) {
            if (command('which', [tool], { mute: true }).status != 0) {
                missingTools.push(tool);
            }
        }
        if (missingTools.length > 0) {
            var msg = 'Missing LLVM tools: ' + missingTools.join(', ') + '\n';
            if (Sys.systemName() == 'Mac') {
                msg += "Install with: brew install llvm lld\n";
                msg += "Then add to PATH: export PATH=\"$(brew --prefix llvm)/bin:$PATH\"";
            } else {
                msg += 'Install with: sudo apt install clang lld llvm';
            }
            fail(msg);
        }
        success('All LLVM tools found.');

        // Step 2: Check for xwin
        var xwinDir = Sys.getEnv('XWIN_DIR');
        if (xwinDir == null || xwinDir == '') {
            var home = Sys.getEnv('HOME');
            if (home == null) home = Sys.getEnv('USERPROFILE');
            xwinDir = Path.join([home, '.ceramic', 'xwin']);
        }

        var forceDownload = args.indexOf('--force') != -1;

        // Check if xwin SDK is already downloaded
        if (!forceDownload && FileSystem.exists(Path.join([xwinDir, 'crt', 'include'])) && FileSystem.exists(Path.join([xwinDir, 'sdk', 'include', 'ucrt']))) {
            print('Windows SDK already exists at: ' + xwinDir);
            print('Use --force to re-download.');
        } else {
            // Find or install xwin
            var xwinBin = findXwin();
            if (xwinBin == null) {
                print('xwin not found. Installing...');
                xwinBin = installXwin();
            }
            if (xwinBin == null) {
                fail('Failed to install xwin. Please install it manually:\n  brew install xwin (macOS)\n  cargo install xwin --locked (any platform)');
            }
            success('Using xwin: ' + xwinBin);

            // Step 3: Download MSVC CRT and Windows SDK
            print('Downloading MSVC CRT and Windows SDK to: ' + xwinDir);
            print('This may take a while (~1.5GB download)...');

            // Ensure parent directory exists
            var xwinParent = Path.directory(xwinDir);
            if (!FileSystem.exists(xwinParent)) {
                FileSystem.createDirectory(xwinParent);
            }

            if (command(xwinBin, ['--accept-license', 'splat', '--output', xwinDir], {}).status != 0) {
                fail('Failed to download Windows SDK with xwin.');
            }
        }

        // Step 4: Verify the SDK
        print('Verifying Windows SDK installation...');
        var requiredPaths = [
            Path.join([xwinDir, 'crt', 'include']),
            Path.join([xwinDir, 'crt', 'lib', 'x86_64']),
            Path.join([xwinDir, 'sdk', 'include', 'ucrt']),
            Path.join([xwinDir, 'sdk', 'include', 'um']),
            Path.join([xwinDir, 'sdk', 'include', 'shared']),
            Path.join([xwinDir, 'sdk', 'lib', 'ucrt', 'x86_64']),
            Path.join([xwinDir, 'sdk', 'lib', 'um', 'x86_64']),
        ];
        for (p in requiredPaths) {
            if (!FileSystem.exists(p)) {
                fail('Windows SDK verification failed. Missing: ' + p);
            }
        }

        success('Windows cross-compilation setup complete!');
        print('SDK location: ' + xwinDir);
        print('');
        print('You can now build Windows apps with: ceramic build windows');
    }

    function findXwin():Null<String> {
        if (command('which', ['xwin'], { mute: true }).status == 0) {
            return 'xwin';
        }
        // Check ~/.ceramic/bin/
        var home = Sys.getEnv('HOME');
        if (home == null) home = Sys.getEnv('USERPROFILE');
        var localBin = Path.join([home, '.ceramic', 'bin', 'xwin']);
        if (FileSystem.exists(localBin)) {
            return localBin;
        }
        return null;
    }

    function installXwin():Null<String> {
        var home = Sys.getEnv('HOME');
        if (home == null) home = Sys.getEnv('USERPROFILE');
        var ceramicBinDir = Path.join([home, '.ceramic', 'bin']);
        if (!FileSystem.exists(ceramicBinDir)) {
            FileSystem.createDirectory(ceramicBinDir);
        }

        var xwinVersion = '0.8.0';

        // Determine platform for binary download
        var os = Sys.systemName();
        var downloadUrl:String = null;
        var archiveName:String = null;

        if (os == 'Linux') {
            // Direct binary download available for Linux
            var arch = getSystemArch();
            if (arch == 'aarch64' || arch == 'arm64') {
                archiveName = 'xwin-$xwinVersion-aarch64-unknown-linux-musl.tar.gz';
            } else {
                archiveName = 'xwin-$xwinVersion-x86_64-unknown-linux-musl.tar.gz';
            }
            downloadUrl = 'https://github.com/Jake-Shadle/xwin/releases/download/$xwinVersion/$archiveName';
        }

        if (downloadUrl != null) {
            // Download and extract binary
            var archivePath = Path.join([ceramicBinDir, archiveName]);
            print('Downloading xwin $xwinVersion...');
            Download.downloadFile(downloadUrl, archivePath);
            print('Extracting xwin...');
            TarGz.untarGzFile(archivePath, ceramicBinDir, ceramicBinDir);
            FileSystem.deleteFile(archivePath);

            // The tarball extracts to a subdirectory, find the binary
            var extractedDir = Path.join([ceramicBinDir, archiveName.replace('.tar.gz', '')]);
            var extractedBin = Path.join([extractedDir, 'xwin']);
            var targetBin = Path.join([ceramicBinDir, 'xwin']);
            if (FileSystem.exists(extractedBin)) {
                if (FileSystem.exists(targetBin)) {
                    FileSystem.deleteFile(targetBin);
                }
                File.copy(extractedBin, targetBin);
                command('chmod', ['+x', targetBin], { mute: true });
                // Clean up extracted directory
                Files.deleteRecursive(extractedDir);
                return targetBin;
            }
        }

        // On macOS, try brew install
        if (os == 'Mac') {
            print('Installing xwin via Homebrew...');
            if (command('brew', ['install', 'xwin'], {}).status == 0) {
                return 'xwin';
            }
            print('Homebrew install failed. Trying cargo...');
        }

        // Fallback: try cargo install
        if (command('which', ['cargo'], { mute: true }).status == 0) {
            print('Installing xwin via cargo...');
            if (command('cargo', ['install', 'xwin', '--locked'], {}).status == 0) {
                return 'xwin';
            }
        }

        return null;
    }

    function getSystemArch():String {
        var result = command('uname', ['-m'], { mute: true });
        if (result.status == 0 && result.stdout != null) {
            return result.stdout.trim();
        }
        return 'x86_64';
    }
}

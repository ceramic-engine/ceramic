package tools.tasks.shade;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;
import tools.TempDirectory;

using StringTools;

class Shade extends Task {

    override public function help(cwd:String):Array<Array<String>> {
        return [
            ['--in <path to haxe shader file>', 'A haxe shader file to convert'],
            ['--out <output directory>', 'The output directory'],
            ['--target', 'The shader target: glsl, unity, custom'],
            ['--hxml', 'Additional hxml to use when transpiling']
        ];
    }

    override public function info(cwd:String):String {
        return "Utility to transpile haxe shaders to their target shader language like GLSL or HLSL/Unity";
    }

    override function run(cwd:String, args:Array<String>):Void {
        var hxFiles:Array<String> = [];
        while (true) {
            var file = extractArgValue(args, 'in', true);
            if (file == null) break;
            if (!Path.isAbsolute(file)) {
                file = Path.join([cwd, file]);
            }
            hxFiles.push(file);
        }

        var outputPath = extractArgValue(args, 'out');
        var target = extractArgValue(args, 'target');
        var hxml = extractArgValue(args, 'hxml');

        if (hxFiles.length == 0) {
            fail('At least one occurence of --in argument is required');
        }

        if (outputPath == null) {
            outputPath = cwd;
        } else if (!Path.isAbsolute(outputPath)) {
            outputPath = Path.join([cwd, outputPath]);
        }

        if (target == null) {
            fail('--target argument is required (glsl, unity, or custom)');
        }

        // Step 1: Create a temporary directory
        var tempDir = TempDirectory.tempDir('shade-compile');

        // Step 2: Copy shader files with correct package structure
        for (hxFile in hxFiles) {
            var pkg = extractPackageFromHaxeFile(hxFile);
            var typeName = getTypeName(hxFile);

            var destPath:String;
            if (pkg != null) {
                var pkgPath = pkg.replace('.', '/');
                destPath = Path.join([tempDir, pkgPath, typeName + '.hx']);
            } else {
                destPath = Path.join([tempDir, typeName + '.hx']);
            }

            Files.copyIfNeeded(hxFile, destPath);
        }

        // Step 3: Generate import.hx
        var importContent = 'import shade.*;\nimport shade.Functions.*;\n';
        File.saveContent(Path.join([tempDir, 'import.hx']), importContent);

        // Step 4: Generate Main.hx
        var mainContent = new StringBuf();
        for (hxFile in hxFiles) {
            var fullType = getFullTypePath(hxFile);
            mainContent.add('import $fullType;\n');
        }
        mainContent.add('\nfunction main() {\n}\n');
        File.saveContent(Path.join([tempDir, 'Main.hx']), mainContent.toString());

        // Step 5: Generate build.hxml
        var ceramicRoot = context.ceramicRootPath;
        var shadePath = Path.join([ceramicRoot, 'git', 'shade', 'src']);
        var reflaxePath = Path.join([ceramicRoot, 'git', 'reflaxe', 'src']);
        var reflaxeExtraParams = Path.join([ceramicRoot, 'git', 'reflaxe', 'extraParams.hxml']);

        var hxmlContent = new StringBuf();

        // Local class path (the temp dir itself)
        hxmlContent.add('-cp .\n');

        // Reflaxe library (by path, not haxelib)
        hxmlContent.add('-cp $reflaxePath\n');
        hxmlContent.add('$reflaxeExtraParams\n');
        hxmlContent.add('-D reflaxe\n');

        // Shade library (by path, not haxelib)
        hxmlContent.add('-cp $shadePath\n');
        hxmlContent.add('-D shade\n');

        // Required haxe compiler settings for reflaxe/shade
        hxmlContent.add('--dce no\n');
        hxmlContent.add('-D analyzer-no-module\n');
        hxmlContent.add('-D retain-untyped-meta\n');

        // Shade compiler initialization
        hxmlContent.add('--macro shade.compiler.CompilerInit.Start()\n');

        // Add target-specific defines
        switch (target) {
            case 'glsl': hxmlContent.add('-D shade_glsl\n');
            case 'unity': hxmlContent.add('-D shade_unity\n');
            case 'custom': hxmlContent.add('-D shade_custom\n');
            default: fail('Unknown target: $target');
        }

        // Set output directory to temp subfolder (not final output)
        var shadeOutputDir = Path.join([tempDir, 'shade-out']);
        hxmlContent.add('-D shade_output=$shadeOutputDir\n');

        // Add user-provided hxml if any
        if (hxml != null) {
            hxmlContent.add('$hxml\n');
        }

        hxmlContent.add('-main Main\n');

        File.saveContent(Path.join([tempDir, 'build.hxml']), hxmlContent.toString());

        // Step 6: Run Haxe compiler
        var result = haxe(['build.hxml'], {cwd: tempDir});
        if (result.status != 0) {
            fail('Shader compilation failed');
        }

        // Step 7: Copy generated shaders to output directory
        if (!FileSystem.exists(outputPath)) {
            FileSystem.createDirectory(outputPath);
        }

        if (FileSystem.exists(shadeOutputDir)) {
            for (file in FileSystem.readDirectory(shadeOutputDir)) {
                if (file == '_GeneratedFiles.json') continue;

                var srcPath = Path.join([shadeOutputDir, file]);
                var dstPath = Path.join([outputPath, file]);

                File.copy(srcPath, dstPath);
            }
        }

        // Step 8: Clean up temporary directory
        Files.deleteRecursive(tempDir);
    }

    /**
     * Extracts the package declaration from a Haxe source file.
     * @param filePath Path to the Haxe file
     * @return The package name (e.g., "some.package.name") or null if no package
     */
    function extractPackageFromHaxeFile(filePath:String):Null<String> {
        var content = File.getContent(filePath);
        var packageRegex = ~/^package\s+([a-zA-Z_][a-zA-Z0-9_\.]*)\s*;/m;
        if (packageRegex.match(content)) {
            return packageRegex.matched(1);
        }
        return null;
    }

    /**
     * Gets the type name from a file path (filename without extension).
     * @param filePath Path to the file
     * @return The type name (e.g., "MyShader" from "/path/to/MyShader.hx")
     */
    function getTypeName(filePath:String):String {
        return Path.withoutExtension(Path.withoutDirectory(filePath));
    }

    /**
     * Gets the full type path (package + type name) for a Haxe file.
     * @param filePath Path to the Haxe file
     * @return The full type path (e.g., "some.package.MyShader")
     */
    function getFullTypePath(filePath:String):String {
        var pkg = extractPackageFromHaxeFile(filePath);
        var typeName = getTypeName(filePath);
        return pkg != null ? '$pkg.$typeName' : typeName;
    }
}
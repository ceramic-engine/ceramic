package tools;

import haxe.crypto.Md5;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class UnityCSharp {

    static final ABSTRACT_GENERIC_CAST = ~/(public (?:virtual|override) object (\w+_cast)<([^>]+)>\(\) \{\n)((?:[ \t]*#line[^\n]*\n)?)([ \t]*)return this\.\2<[^>]+>\(\);\n/g;

    static final STATIC_GENERIC_CAST = ~/public static object __hx_cast<([^>]+)>\((global::[\w.@]+) me\) \{\n((?:[ \t]*#line[^\n]*\n)?)([ \t]*)return \( \(\( me != null \)\) \? \(me\.(\w+_cast)<[^>]+>\(\)\) : default\(object\) \);\n/g;

    static final ARRAY_LENGTH = ~/\( ((?:this\.)?\w+) as global::System\.Array \)\.Length/g;

    public static function exportScriptFilesToProject(cwd:String, project:Project) {

        var debug = context.debug;
        var variant = context.variant;
        var outTargetPath = BuildTargetExtensions.outPathWithName('unity', 'unity', cwd, debug, variant);
        var unityProjectPath = UnityProject.resolveUnityProjectPath(cwd, project);

        var srcCsPath = Path.join([outTargetPath, 'bin', 'src']);
        var dstCsPath = Path.join([unityProjectPath, 'Assets', 'Ceramic', 'Scripts']);

        var dstResourcesPath = Path.join([unityProjectPath, 'Assets', 'Ceramic', 'Resources']);

        // List source files
        var srcList = Files.getFlatDirectory(srcCsPath);
        var srcNames = new Map<String,Bool>();
        for (name in srcList) {
            srcNames.set(sanitizeName(name), true);
        }

        // List existing destination files
        var dstList = [];
        if (FileSystem.exists(dstCsPath)) {
            dstList = Files.getFlatDirectory(dstCsPath);
        }
        var dstNames = new Map<String,Bool>();
        for (name in dstList) {
            dstNames.set(name, true);
        }

        // Then update or create every file
        for (name in srcList) {

            // Only process C# files
            if (name.endsWith('.cs')) {

                var srcFilePath = Path.join([srcCsPath, name]);
                var srcContent = File.getContent(srcFilePath);
                var processedContent = processScriptContent(srcContent);
                var normalizedPath = Path.normalize(name);
                if (normalizedPath == 'cs/internal/FieldLookup.cs') {
                    processedContent = patchFieldLookup(processedContent, dstResourcesPath);
                }
                else if (normalizedPath == 'cs/internal/Runtime.cs') {
                    processedContent = patchRuntime(processedContent, dstResourcesPath);
                }
                else if (normalizedPath == 'haxe/ds/IntMap.cs' || normalizedPath == 'haxe/ds/StringMap.cs') {
                    processedContent = patchMapGenericCast(processedContent);
                }
                else if (normalizedPath == 'Array.cs') {
                    processedContent = patchGenericCast(processedContent);
                    processedContent = patchArraySort(processedContent);
                    processedContent = patchArrayLength(processedContent);
                }

                var sanitizedName = sanitizeName(normalizedPath);

                var dstFilePath = Path.join([dstCsPath, sanitizedName]);
                var existingContent = null;

                if (dstNames.exists(sanitizedName)) {
                    existingContent = File.getContent(dstFilePath);
                }

                if (processedContent != existingContent) {
                    // Content is different
                    if (!dstNames.exists(sanitizedName)) {
                        // Check that intermediate directories are created
                        var directory = Path.directory(dstFilePath);
                        if (!FileSystem.exists(directory)) {
                            FileSystem.createDirectory(directory);
                        }
                    }
                    // Copy file content!
                    File.saveContent(dstFilePath, processedContent);
                }
            }
        }

        // Haxe resources (`--resource file@name`)
        exportResourcesToProject(Path.join([srcCsPath, 'Resources']), Path.join([dstResourcesPath, 'haxe_resources']));

        // Remove outdated files
        for (name in dstList) {

            // Only process C# files
            if (name.endsWith('.cs')) {
                if (!srcNames.exists(name)) {
                    // Found outdated file, remove it
                    var outdatedFilePath = Path.join([dstCsPath, name]);
                    if (FileSystem.exists(outdatedFilePath)) {
                        FileSystem.deleteFile(outdatedFilePath);
                    }
                    // Remove related meta file (if any)
                    var outdatedMeta = outdatedFilePath + '.meta';
                    if (FileSystem.exists(outdatedMeta)) {
                        FileSystem.deleteFile(outdatedMeta);
                    }
                }
            }

        }

    }

    /**
     * Copies the resources written by Haxe's C# target (`bin/src/Resources`)
     * as `.bytes` text assets that the Unity `haxe.Resource` loads, and removes
     * the outdated ones.
     */
    static function exportResourcesToProject(srcResourcesPath:String, dstResourcesPath:String) {

        var srcNames = new Map<String,Bool>();
        if (FileSystem.exists(srcResourcesPath)) {
            for (name in FileSystem.readDirectory(srcResourcesPath)) {
                var srcFilePath = Path.join([srcResourcesPath, name]);
                if (FileSystem.isDirectory(srcFilePath))
                    continue;
                srcNames.set(name + '.bytes', true);
                var dstFilePath = Path.join([dstResourcesPath, name + '.bytes']);
                var content = File.getBytes(srcFilePath);
                if (FileSystem.exists(dstFilePath) && File.getBytes(dstFilePath).compare(content) == 0)
                    continue;
                if (!FileSystem.exists(dstResourcesPath)) {
                    FileSystem.createDirectory(dstResourcesPath);
                }
                File.saveBytes(dstFilePath, content);
            }
        }

        if (FileSystem.exists(dstResourcesPath)) {
            for (name in FileSystem.readDirectory(dstResourcesPath)) {
                if (name.endsWith('.bytes') && !srcNames.exists(name)) {
                    var outdatedFilePath = Path.join([dstResourcesPath, name]);
                    FileSystem.deleteFile(outdatedFilePath);
                    if (FileSystem.exists(outdatedFilePath + '.meta')) {
                        FileSystem.deleteFile(outdatedFilePath + '.meta');
                    }
                }
            }
        }

    }

    static function sanitizeName(name:String):String {

        var sanitizedNameParts = Path.normalize(name).split('/');
        for (i in 0...sanitizedNameParts.length) {
            var part = sanitizedNameParts[i];
            if (part == 'editor') {
                sanitizedNameParts[i] = '_editor';
            }
        }
        return sanitizedNameParts.join('/');

    }

    static function processScriptContent(content:String):String {

        // Disable stripping
        //content = '[assembly: Preserve] ' + content;

        // content = 'using Unity.IL2CPP.CompilerServices;\n' + content;

        // content = content.replace('\tpublic class ', '\t[Il2CppSetOption(Option.NullChecks, false)]\n\t[Il2CppSetOption(Option.ArrayBoundsChecks, false)]\n\tpublic class ');
        // content = content.replace('\tpublic sealed class ', '\t[Il2CppSetOption(Option.NullChecks, false)]\n\t[Il2CppSetOption(Option.ArrayBoundsChecks, false)]\n\tpublic class ');

        // Somehow, there are cases where System is not marked with global:: and that conflicts with ceramic's System class
        content = content.replace('\tSystem.Type', '\tglobal::System.Type');
        content = content.replace('(System.Type', '(global::System.Type');
        content = content.replace('(System.Threading', '(global::System.Threading');
        content = content.replace('\tSystem.Threading', '\tglobal::System.Threading');

        // Disable Timer.getTime() warning
        // TODO: fix the actual code!
        content = content.replace('#pragma warning disable ', '#pragma warning disable 618, ');

        // Mute hidden inherited member
        content = content.replace('#pragma warning disable ', '#pragma warning disable 108, ');

        // Haxe's C# target gives a generic abstract class a cast method that
        // calls itself (it cannot create an instance to copy the fields into,
        // like it does for other generic classes): any cast to that class
        // overflowed the stack. Return the instance itself: same type
        // arguments are the usual case, and the caller's C# cast fails
        // cleanly otherwise.
        if (content.indexOf('_cast<') != -1) {
            content = ABSTRACT_GENERIC_CAST.map(content, function(r) {
                return r.matched(1) + r.matched(4) + r.matched(5) + 'return this;\n';
            });
        }

        // Haxe's C# target casts to a generic class through a static
        // `__hx_cast<T>(me)` that calls the generic virtual method
        // `me.<class>_cast<T>()`, which compares `typeof` the type arguments
        // before returning the instance itself. On IL2CPP, a generic virtual
        // call is resolved through a locked hash table and `typeof` in shared
        // generic code through a reflection lookup: about 9 % of a frame of
        // the GPUI story on Unity (taffy reads its nodes this way). Return the
        // instance at once when it already has the target type (what the cast
        // method returns in that case anyway).
        if (content.indexOf('public static object __hx_cast<') != -1) {
            content = STATIC_GENERIC_CAST.map(content, function(r) {
                var typeParams = r.matched(1);
                var castMethod = r.matched(5);
                return r.matched(0).replace(
                    '? (me.' + castMethod + '<' + typeParams + '>())',
                    '? ((me is ' + r.matched(2) + '<' + typeParams + '>) ? (object) me : me.' + castMethod + '<' + typeParams + '>())'
                );
            });
        }

        return content;

    }

    static function patchFieldLookup(content:String, dstResourcesPath:String):String {

        // Extract field ids
        var fieldIdsDecl = 'protected static int[] fieldIds = new int[]{';
        var fieldIdsIndex = content.indexOf(fieldIdsDecl);
        if (fieldIdsIndex != -1) {
            var fieldIdsEndIndex = content.indexOf('};', fieldIdsIndex + fieldIdsDecl.length);
            var fieldIdsData = content.substring(fieldIdsIndex + fieldIdsDecl.length, fieldIdsEndIndex).replace(' ', '').replace(',', "\n").trim();
            var numFieldIds = fieldIdsData.split("\n").length;
            var fieldIdsHash = Md5.encode(fieldIdsData);
            var fieldIdsFilePath = Path.join([dstResourcesPath, 'lookup_i.txt']);

            // Save data as a text asset
            var existingFieldIdsData = null;
            if (FileSystem.exists(fieldIdsFilePath)) {
                existingFieldIdsData = File.getContent(fieldIdsFilePath);
            }
            if (fieldIdsData != existingFieldIdsData) {
                if (!FileSystem.exists(dstResourcesPath)) {
                    FileSystem.createDirectory(dstResourcesPath);
                }
                File.saveContent(fieldIdsFilePath, fieldIdsData);
            }

            // Patch C# script to make it load text asset data instead of embedding array
            var patchedFieldIds = 'protected static int[] fieldIds = global::backend.FieldLookup.loadFieldIds($numFieldIds, "$fieldIdsHash");';
            content = content.substring(0, fieldIdsIndex) + patchedFieldIds + content.substring(fieldIdsEndIndex + 2);
        }
        else {
            warning('Failed to patch field lookup ids');
        }

        // Extract field names
        var fieldNamesDecl = 'protected static string[] fields = new string[]{"';
        var fieldNamesIndex = content.indexOf(fieldNamesDecl);
        if (fieldNamesIndex != -1) {
            var fieldNamesEndIndex = content.indexOf('"};', fieldNamesIndex + fieldNamesDecl.length);
            var fieldNamesData = content.substring(fieldNamesIndex + fieldNamesDecl.length, fieldNamesEndIndex).replace(' ', '').replace('","', "\n").trim();
            var numFieldNames = fieldNamesData.split("\n").length;
            var fieldNamesHash = Md5.encode(fieldNamesData);
            var fieldNamesFilePath = Path.join([dstResourcesPath, 'lookup_s.txt']);

            // Save data as a text asset
            var existingFieldNamesData = null;
            if (FileSystem.exists(fieldNamesFilePath)) {
                existingFieldNamesData = File.getContent(fieldNamesFilePath);
            }
            if (fieldNamesData != existingFieldNamesData) {
                if (!FileSystem.exists(dstResourcesPath)) {
                    FileSystem.createDirectory(dstResourcesPath);
                }
                File.saveContent(fieldNamesFilePath, fieldNamesData);
            }

            // Patch C# script to make it load text asset data instead of embedding array
            var patchedFieldNames = 'protected static string[] fields = global::backend.FieldLookup.loadFieldNames($numFieldNames, "$fieldNamesHash");';
            content = content.substring(0, fieldNamesIndex) + patchedFieldNames + content.substring(fieldNamesEndIndex + 3);
        }
        else {
            warning('Failed to patch field lookup names');
        }

        return content;

    }

    static function patchGenericCast(content:String):String {

        content = content.replace('global::haxe.lang.Runtime.genericCast<T>(this.__a[', '(this.__a[');
        content = content.replace('global::haxe.lang.Runtime.genericCast<T>(x', '(x');

        return content;

    }

    /**
     * `IntMap<T>` and `StringMap<T>` keep their values in a `T[]` but read
     * them through `Runtime.genericCast<T>`, a type test that IL2CPP runs
     * through its slow path when `T` is a reference type: read them as they
     * are, like `Array.__get` (`patchGenericCast`).
     */
    static function patchMapGenericCast(content:String):String {

        content = content.replace('global::haxe.lang.Runtime.genericCast<T>(this.vals[', '(this.vals[');
        content = content.replace('global::haxe.lang.Runtime.genericCast<T>(vals[', '(vals[');
        content = content.replace('global::haxe.lang.Runtime.genericCast<T>(this.m.vals[', '(this.m.vals[');

        return content;

    }

    /**
     * Haxe's C# `Array` reads the length of its native `T[]` through
     * `(a as System.Array).Length`, which IL2CPP compiles to two calls into
     * the runtime (`GetLength(0)` and `Rank`), on every `push` and every
     * write by index. Read the length of the `T[]` directly.
     */
    static function patchArrayLength(content:String):String {

        return ARRAY_LENGTH.replace(content, '$1.Length');

    }

    /**
     * Haxe's C# `Array.sort` is a quicksort: not stable, while hxcpp
     * (`std::stable_sort`) and JavaScript keep equal elements in their order,
     * which code ported from stable sorts relies on. Replace it with a stable
     * merge sort (an element moves before an earlier one only when the
     * comparison says it is smaller, like `std::stable_sort`).
     */
    static function patchArraySort(content:String):String {

        var sortDecl = 'public void sort(global::haxe.lang.Function f) {';
        var sortIndex = content.indexOf(sortDecl);
        var quicksortIndex = content.indexOf('public void quicksort(', sortIndex);
        if (sortIndex == -1 || quicksortIndex == -1) {
            warning('Failed to patch Array.sort');
            return content;
        }

        var stableSort = [
            sortDecl,
            '\t\t\tunchecked {',
            '\t\t\t\tint n = this.length;',
            '\t\t\t\tif (n < 2) {',
            '\t\t\t\t\treturn;',
            '\t\t\t\t}',
            '\t\t\t\tT[] src = this.__a;',
            '\t\t\t\tT[] dst = new T[n];',
            '\t\t\t\tfor (int width = 1; width < n; width *= 2) {',
            '\t\t\t\t\tfor (int lo = 0; lo < n; lo += 2 * width) {',
            '\t\t\t\t\t\tint mid = global::System.Math.Min(lo + width, n);',
            '\t\t\t\t\t\tint hi = global::System.Math.Min(lo + 2 * width, n);',
            '\t\t\t\t\t\tint i = lo;',
            '\t\t\t\t\t\tint j = mid;',
            '\t\t\t\t\t\tint k = lo;',
            '\t\t\t\t\t\twhile (i < mid && j < hi) {',
            '\t\t\t\t\t\t\tif (((int) (f.__hx_invoke2_f(default(double), (object) src[j], default(double), (object) src[i]))) < 0) {',
            '\t\t\t\t\t\t\t\tdst[k++] = src[j++];',
            '\t\t\t\t\t\t\t}',
            '\t\t\t\t\t\t\telse {',
            '\t\t\t\t\t\t\t\tdst[k++] = src[i++];',
            '\t\t\t\t\t\t\t}',
            '\t\t\t\t\t\t}',
            '\t\t\t\t\t\twhile (i < mid) {',
            '\t\t\t\t\t\t\tdst[k++] = src[i++];',
            '\t\t\t\t\t\t}',
            '\t\t\t\t\t\twhile (j < hi) {',
            '\t\t\t\t\t\t\tdst[k++] = src[j++];',
            '\t\t\t\t\t\t}',
            '\t\t\t\t\t}',
            '\t\t\t\t\tT[] swap = src;',
            '\t\t\t\t\tsrc = dst;',
            '\t\t\t\t\tdst = swap;',
            '\t\t\t\t}',
            '\t\t\t\tif (src != this.__a) {',
            '\t\t\t\t\tglobal::System.Array.Copy(src, 0, this.__a, 0, n);',
            '\t\t\t\t}',
            '\t\t\t}',
            '\t\t}',
            '\t\t',
            '\t\t',
            '\t\t'
        ].join('\n');

        return content.substring(0, sortIndex) + stableSort + content.substring(quicksortIndex);

    }

    static function patchRuntime(content:String, dstResourcesPath:String):String {

        var indexOfConstructor = content.indexOf('public Runtime() {');

        if (indexOfConstructor != -1) {

            var overloads = [];

            overloads.push('public static int toInt(int val) { return val; }');
            overloads.push('public static int toInt(float val) { return (int)val; }');
            overloads.push('public static int toInt(double val) { return (int)val; }');

            overloads.push('public static double toDouble(int val) { return (double)val; }');
            overloads.push('public static double toDouble(float val) { return (double)val; }');
            overloads.push('public static double toDouble(double val) { return val; }');

            content = content.substring(0, indexOfConstructor) + overloads.join('\n') + '\n' + content.substring(indexOfConstructor);

        }

        return content;

    }

}
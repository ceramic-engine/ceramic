package tools;

import npm.Glob;
import npm.IsTextOrBinary;
import npm.Handlebars;
import tools.Tools.*;
import tools.Project;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import js.node.Fs;

using StringTools;

class Templates {

    public static function replaceInContents(path:String, replacements:Map<String,String>):Void {

        var projectPath = shared.cwd;

        // Perform content replaces
        //
        for (filePath in Glob.sync(Path.join([projectPath, '**']), {dot: true})) {

            // Check if file is a text file
            var isTextFile = false;

            // If file is not a directory
            var textExts = 'strings m h json xcworkspacedata pbxproj pch plist yml yaml xml iml'.split(' ');
            var binaryExts = 'png jpg jpeg data zip a'.split(' ');
            if (!Fs.lstatSync(filePath).isDirectory()) {

                // Check extension
                var fileExt = filePath.indexOf('.') == -1 ? null : filePath.substr(filePath.indexOf('.') + 1);
                if (fileExt == null || fileExt.trim() == '') {
                    isTextFile = IsTextOrBinary.isTextSync(filePath, Fs.readFileSync(filePath));
                }
                else if (textExts.indexOf(fileExt) != -1) {
                    isTextFile = true;
                }
                else if (binaryExts.indexOf(fileExt) != -1) {
                    isTextFile = false;
                }
                else {
                    isTextFile = IsTextOrBinary.isTextSync(filePath, Fs.readFileSync(filePath));
                }

                // If it is a text file, perform replace
                if (isTextFile) {
                    var str = sys.io.File.getContent(filePath);
                    var prevStr = str;
                    for (key in replacements.keys()) {
                        str = str.replace(key, replacements[key]);
                    }
                    if (prevStr != str) sys.io.File.saveContent(filePath, str);
                }
            }

        }

    } //replaceInNamesAndContents

    public static function replaceInNames(path:String, replacements:Map<String,String>):Void {

        var projectPath = shared.cwd;

        // Perform file/directory renames
        //
        for (key in replacements.keys()) {
            var value = replacements[key];

            while (true) {

                var didRenameAFile = false;

                for (filePath in Glob.sync(Path.join([projectPath, '**']), {dot: true})) {
                    if (FileSystem.exists(filePath) && filePath.indexOf(key) != -1) {
                        var newFilePath = projectPath + filePath.substr(projectPath.length).replace(key, value);
                        Fs.renameSync(filePath, newFilePath);
                        didRenameAFile = true;
                    }
                }

                if (!didRenameAFile) break;
            }
        }

    } //replaceInNames

    public static function evalTemplate(tplPath:String, project:Project, ?extraContext:Dynamic):String {

        // Create context
        //
        var context:Dynamic = {};
        context.ceramicPath = settings.ceramicPath;
        context.projectPath = shared.cwd;
        context.defines = settings.defines;

        var app = project.app;

        for (key in Reflect.fields(app)) {
            Reflect.setField(context, key, Reflect.field(app, key));
        }

        if (extraContext != null) {
            for (key in Reflect.fields(extraContext)) {
                Reflect.setField(context, key, Reflect.field(extraContext, key));
            }
        }

        // Get template contents
        var templateContents = sys.io.File.getContent(tplPath);

        // Create handlebars template
        var template = Handlebars.compile(templateContents);

        return template(context);

    } //evalTemplateForApp

} //Templates

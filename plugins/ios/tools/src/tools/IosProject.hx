package tools;

import tools.Tools.*;
import tools.Project;
import tools.Templates;
import tools.Sync;
import haxe.io.Path;
import sys.FileSystem;
import npm.Ncp;

class IosProject {

    function createIosProjectIfNeeded(path:String, project:Project):Void {

        var iosProjectName = project.app.name;
        var iosProjectPath = path;
        var iosProjectFile = Path.join([iosProjectPath, iosProjectName, iosProjectName + '.xcodeproj']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(iosProjectFile)) {

            // Create directory if needed
            if (!FileSystem.exists(iosProjectPath)) {
                FileSystem.createDirectory(iosProjectPath);
            }

            // Copy from template project
            print('Copy from Xcode project template');
            Sync.run(function(done) {

                Ncp.ncp(
                    Path.join([settings.ceramicPath, 'tpl/ios/project/MyProject']),
                    iosProjectPath,
                    null,
                    function(err) {
                        if (err != null) throw err;
                        done();
                    }
                );

            });

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['MyProject'] = project.app.name;
            Templates.replaceInNames(iosProjectPath, replacementsInNames);

            // Replace in contents
            print('Perform replaces in contents');
            var replacementsInContents = new Map<String,String>();
            if (project.app.company != null) {
                replacementsInContents['My Company'] = project.app.company;
            }
            replacementsInContents['mycompany.MyProject'] = Reflect.field(project.app, 'package');
            replacementsInContents['MyProject'] = project.app.name;
            replacementsInContents['My Project'] = project.app.displayName;
            Templates.replaceInContents(iosProjectPath, replacementsInContents);
        }

    } //createIosProjectIfNeeded

} //IosProject

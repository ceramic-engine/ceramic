package tools.tasks.ios;

import tools.Helpers.*;
import haxe.io.Path;
#if (haxe_ver >= 4)
import haxe.SysTools;
#end
import sys.FileSystem;
import sys.io.File;
import tools.IosProject;

import js.node.ChildProcess;

using StringTools;

class ProfileUUID extends tools.Task {

    override public function info(cwd:String):String {

        return "Extract a provisioning profile's UUID.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var provisioningProfilePath = extractArgValue(args, 'path');
        if (!Path.isAbsolute(provisioningProfilePath)) {
            provisioningProfilePath = Path.join([cwd, provisioningProfilePath]);
        }

        // Extract provisioning profile UUID
        #if (haxe_ver < 4)
        var provisioningUUID = ('' + ChildProcess.execSync("/usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin <<< $(security cms -D -i " + StringTools.quoteUnixArg(provisioningProfilePath) + ")")).trim();
        #else
        var provisioningUUID = ('' + ChildProcess.execSync("/usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin <<< $(security cms -D -i " + SysTools.quoteUnixArg(provisioningProfilePath) + ")")).trim();
        #end

        // Check result
        if (provisioningUUID == null || provisioningUUID.trim() == '') {
            fail('Failed to retrieve UUID of provisioning profile: $provisioningProfilePath');
        }

        // Print result
        print(provisioningUUID);

    }

}

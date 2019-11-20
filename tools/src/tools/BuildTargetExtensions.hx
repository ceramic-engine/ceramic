package tools;

import haxe.io.Path;
import tools.Helpers.*;

class BuildTargetExtensions {

    public static function outPath(target:BuildTarget, group:String, ?cwd:String, ?debug:Bool, ?variant:String):String {

        if (cwd == null) cwd = context.cwd;
        if (debug == null) debug = context.debug;
        if (variant == null) variant = context.variant;

        return outPathWithName(group, target.name, cwd, debug, variant);

    } //outPath

    public static function outPathWithName(group:String, targetName:String, ?cwd:String, ?debug:Bool, ?variant:String):String {

        if (cwd == null) cwd = context.cwd;
        if (debug == null) debug = context.debug;
        if (variant == null) variant = context.variant;

        return Path.join([cwd, 'out', group, targetName + (variant != 'standard' ? '-' + variant : '') + (debug ? '-debug' : '')]);

    } //outPath

} //BuildTargetExtensions

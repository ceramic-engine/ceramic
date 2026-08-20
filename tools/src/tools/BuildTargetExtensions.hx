package tools;

import haxe.io.Path;
import tools.Helpers.*;

class BuildTargetExtensions {

    public static function outPath(target:BuildTarget, group:String, ?cwd:String, ?debug:Bool, ?variant:String):String {

        if (cwd == null) cwd = context.cwd;
        if (debug == null) debug = context.debug;
        if (variant == null) variant = context.variant;

        return outPathWithName(group, target.name, cwd, debug, variant);

    }

    public static function outPathWithName(group:String, targetName:String, ?cwd:String, ?debug:Bool, ?variant:String):String {

        if (cwd == null) cwd = context.cwd;
        if (debug == null) debug = context.debug;
        if (variant == null) variant = context.variant;

        // The cppia split (native host + .cppia client) must not share the
        // C++ output directory with a standard build, or the two clobber each
        // other. Insert a `-cppia` segment (after any variant, before -debug)
        // so e.g. out/clay/mac, out/clay/mac-cppia, out/clay/mac-cppia-debug
        // and out/clay/mac-<variant>-cppia-debug all stay distinct.
        var cppia = context.defines.exists('ceramic_cppia');

        return Path.join([cwd, 'out', group, targetName + (variant != 'standard' ? '-' + variant : '') + (cppia ? '-cppia' : '') + (debug ? '-debug' : '')]);

    }

}

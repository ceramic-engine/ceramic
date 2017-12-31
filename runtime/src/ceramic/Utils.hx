package ceramic;

import haxe.io.Path;

using StringTools;

/** Various utilities. Some of them are used by ceramic itself or its backends. */
class Utils {

    public static function realPath(path:String):String {

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        return path;

    } //realPath

} //Utils

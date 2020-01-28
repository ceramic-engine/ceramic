package ceramic;

using StringTools;

class AssetPathInfo {

/// Properties

    public var density:Float;

    public var extension:String;

    public var name:String;

    public var path:String;

    public var flags:Map<String,Dynamic>;

/// Constructor

    public function new(path:String) {

        this.path = path;

        var dotIndex = path.lastIndexOf('.');
        extension = path.substr(dotIndex + 1).toLowerCase();

        var truncatedName = path.substr(0, dotIndex);
        var baseAtIndex = truncatedName.lastIndexOf('@');

        density = 1;
        if (baseAtIndex == -1) {
            baseAtIndex = dotIndex;
        }
        else {
            var afterAtParts = truncatedName.substr(baseAtIndex + 1);
            for (afterAt in afterAtParts.split('+')) {
                var isFlag = true;
                if (afterAt.endsWith('x')) {
                    var flt = Std.parseFloat(afterAt.substr(0, afterAt.length-1));
                    if (!Math.isNaN(flt)) {
                        density = flt;
                        isFlag = false;
                    }
                }
                if (isFlag) {
                    if (flags == null) flags = new Map();
                    var equalIndex = afterAt.indexOf('=');
                    if (equalIndex == -1) {
                        flags.set(afterAt, true);
                    } else {
                        var key = afterAt.substr(0, equalIndex);
                        var val = afterAt.substr(equalIndex + 1);
                        flags.set(key, val);
                    }
                }
            }
        }

        name = path.substr(0, cast Math.min(baseAtIndex, dotIndex));

    }

    function toString():String {

        return '' + {extension: extension, name: name, path: path, density: density};

    }

}

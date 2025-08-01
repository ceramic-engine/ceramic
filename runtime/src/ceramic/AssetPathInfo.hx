package ceramic;

using StringTools;

/**
 * Information extracted from a raw asset path.
 * 
 * This class parses asset file paths to extract metadata including:
 * - Density information (e.g., @2x, @3x)
 * - File extension
 * - Normalized asset name
 * - Flags for conditional loading
 * 
 * Path parsing examples:
 * - `hero.png` -> name: "hero", extension: "png", density: 1.0
 * - `hero@2x.png` -> name: "hero", extension: "png", density: 2.0
 * - `hero@2x+retina.png` -> name: "hero", extension: "png", density: 2.0, flags: {retina: true}
 * - `ui/button+hover+pressed.png` -> name: "ui/button", flags: {hover: true, pressed: true}
 * - `icon+size=large.png` -> name: "icon", flags: {size: "large"}
 * 
 * @see Assets.decodePath
 */
class AssetPathInfo {

/// Properties

    /**
     * Density value resolved from file name.
     * Example: If file is named `someImage@2x.png`, density will be `2`.
     * Default density is `1`
     */
    public var density:Float;

    /**
     * File extension (always converted to lowercase for convenience)
     */
    public var extension:String;

    /**
     * Normalized asset name (includes subdirectories relative to asset root).
     * Example: both `someImage.png` and `someImage@2x.png` will resolve to a same asset name `someImage`
     */
    public var name:String;

    /**
     * Original path used to generated path info
     */
    public var path:String;

    /**
     * Flags are extracted from file path.
     * Example: file `someFile+myTag.txt` will generate `myTag` flag.
     */
    public var flags:Map<String,Dynamic>;

/// Constructor

    /**
     * Parse an asset path to extract metadata.
     * @param path The asset file path to parse
     */
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

    /**
     * String representation for debugging.
     * @return Object-like string with all parsed properties
     */
    function toString():String {

        return '' + {extension: extension, name: name, path: path, density: density};

    }

}

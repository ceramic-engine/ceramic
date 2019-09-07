package ceramic;

using StringTools;

/** Pixels class represents an image that can be edited at pixel level.
    It can then be turned into a texture to be drawn on screen. */
class Pixels extends Entity {

/// Properties

    public var width(default,null):Int;

    public var height(default,null):Int;

    public var buffer:Float32Array;

    public var asset:ImageAsset;

/// Lifecycle

    public function new() {

    } //new

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

    } //destroy

/// Print

    override function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('pixels:')) name = name.substr(8);
            return 'Pixels($name $width $height)';
        } else {
            return 'Pixels($width $height)';
        }

    } //toString

} //Image

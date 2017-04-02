package ceramic;

class Texture implements Shortcuts {

/// Properties

    public var width(default,null):Float;

    public var height(default,null):Float;

    public var density(default,set):Float;
    function set_density(density:Float):Float {
        if (this.density == density) return density;
        this.density = density;
        width = app.backend.textures.getWidth(backendItem);
        height = app.backend.textures.getHeight(backendItem);
        return density;
    }

    public var backendItem:backend.Textures.Texture;

/// Lifecycle

    public function new(backendItem:backend.Textures.Texture, density:Float = 1) {

        this.backendItem = backendItem;
        this.density = density;

    } //new

} //Texture

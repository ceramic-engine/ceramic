package ceramic;

import ceramic.Shortcuts.*;

/**
 * Just a regular quad (transparent by default) with a few addition to make it more convenient when used as a layer
 */
@editable({
    implicitSizeUnlessNull: 'texture'
})
class Layer extends Quad {

    @event function resize(width:Float, height:Float);

    var sizeDirty:Bool = false;

    public function new() {

        super();

        transparent = true;

    }

    function emitResizeIfNeeded() {

        if (destroyed || !sizeDirty)
            return;

        sizeDirty = false;

        emitResize(width, height);

    }

    function willEmitResize(width:Float, height:Float):Void {

        // Implemented to allow subclass overrides

    }

    function didEmitResize(width:Float, height:Float):Void {

        // Implemented to allow subclass overrides

    }

    override function set_width(width:Float):Float {
        if (_width == width) return width;
        super.set_width(width);
        if (!sizeDirty) {
            sizeDirty = true;
            app.onceImmediate(emitResizeIfNeeded);
        }
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        super.set_height(height);
        if (!sizeDirty) {
            sizeDirty = true;
            app.onceImmediate(emitResizeIfNeeded);
        }
        return height;
    }

#if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('width', 100);
        entityData.props.set('height', 100);

    }

#end

}

package ceramic;

import ceramic.Shortcuts.*;

/**
 * An utility to display visible bounds on any visual
 */
class VisibleBounds extends Entity implements Component {

    var entity:Visual;

    var bounds:Visual = null;

    /// Lifecycle

    public function new(bounds:Visual) {

        super();

        this.bounds = bounds;

    }

    function bindAsComponent():Void {

        entity.add(bounds);
        app.onUpdate(this, updateBounds);
        updateBounds(0);

    }

    function updateBounds(delta:Float) {

        bounds.pos(0, 0);
        bounds.size(entity.width, entity.height);

    }

}

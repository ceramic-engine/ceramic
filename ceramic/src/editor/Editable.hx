package editor;

import ceramic.Component;
import ceramic.Visual;
import ceramic.Scene;
import ceramic.Point;
import ceramic.Color;
import ceramic.Quad;
import ceramic.Transform;
import ceramic.TouchInfo;
import ceramic.Shortcuts.*;

class Editable extends Component {

    public static var highlight:Highlight;

    static var active:Editable = null;

    var entity:Visual;

    var scene:Scene;

    var point:Point = { x: 0, y: 0 };

    function new(scene:Scene) {
        
        super();
        this.scene = scene;

    } //new

    function init() {

        entity.onDown(this, handleDown);

    } //init

    function destroy() {

        if (active == this && highlight != null) {
            highlight.destroy();
        }

    } //destroy

/// Public API

    public function select() {

        if (active == this) return;
        active = this;
        
        if (highlight != null) {
            highlight.destroy();
        }
        highlight = new Highlight();
        highlight.onceDestroy(function() {
            if (active == this) {
                active = null;

                // Set selected item
                project.send({
                    type: 'set/ui.selectedItemId',
                    value: null
                });
            }
            app.offUpdate(update);
            highlight = null;
        });

        highlight.anchor(0, 0);
        highlight.pos(0, 0);
        highlight.depth = 99999;
        highlight.transform = new Transform();
        highlight.wrapVisual(entity);

        app.onUpdate(this, update);

        // Set selected item
        project.send({
            type: 'set/ui.selectedItemId',
            value: entity.name
        });

    } //select

    function update(_) {

        if (active != this) return;

        highlight.wrapVisual(entity);

    } //update

/// Clicked

    function handleDown(info:TouchInfo) {

        // Ensure this item is selected
        select();

        // Start dragging
        var entityStartX = entity.x;
        var entityStartY = entity.y;
        scene.screenToVisual(screen.pointerX, screen.pointerY, point);
        var dragStartX = point.x;
        var dragStartY = point.y;

        function onMove(info:TouchInfo) {
            project.render();

            scene.screenToVisual(screen.pointerX, screen.pointerY, point);
            entity.x = entityStartX + point.x - dragStartX;
            entity.y = entityStartY + point.y - dragStartY;

        }
        screen.onMove(this, onMove);

        screen.onceUp(this, function(info) {
            project.render();

            screen.offMove(onMove);

            entity.x = Math.round(entity.x);
            entity.y = Math.round(entity.y);

            // Update pos on react side
            project.send({
                type: 'set/ui.selectedItem.x',
                value: entity.x
            });
            project.send({
                type: 'set/ui.selectedItem.y',
                value: entity.y
            });

        });

    } //handleDown

} //Editable

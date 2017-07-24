package editor;

import ceramic.Component;
import ceramic.Visual;
import ceramic.Scene;
import ceramic.Shortcuts.*;

class Editable extends Component {

    public static var highlight:Highlight;

    static var active:Editable = null;

    var entity:Visual;

    var scene:Scene;

    function new(scene:Scene) {
        
        super();
        this.scene = scene;

    } //new

    function init() {

        entity.onDown(this, function(info) {

            // Ensure this item is selected
            select();

        });

    } //init

    function update(_) {

        if (active != this) return;

        highlight.size(entity.width / entity.scaleX, entity.height / entity.scaleY);
        highlight.cornerSize = 7.0 / scene.scaleX;
        highlight.borderSize = 1.5 / scene.scaleX;

    } //update

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
        highlight.size(entity.width / entity.scaleX, entity.height / entity.scaleY);
        highlight.depth = 99999; // We want it above everything
        highlight.cornerSize = 7.0 / scene.scaleX;
        highlight.borderSize = 1.5 / scene.scaleX;
        entity.add(highlight);

        app.onUpdate(this, update);

        // Set selected item
        project.send({
            type: 'set/ui.selectedItemId',
            value: entity.name
        });

    } //select

} //Editable

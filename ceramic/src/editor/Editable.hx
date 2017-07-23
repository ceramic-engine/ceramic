package editor;

import ceramic.Component;
import ceramic.Visual;
import ceramic.Scene;
import ceramic.Shortcuts.*;

class Editable extends Component {

    static var highlight:Highlight;

    var entity:Visual;

    var active:Bool = false;

    var scene:Scene;

    function new(scene:Scene) {
        
        super();
        this.scene = scene;

    } //new

    function init() {

        entity.onDown(this, function(info) {

            active = true;
            
            if (highlight == null) {
                highlight = new Highlight();
                highlight.onceDestroy(function() {
                    highlight = null;
                });
            }

            highlight.anchor(0, 0);
            highlight.pos(0, 0);
            highlight.size(entity.width / entity.scaleX, entity.height / entity.scaleY);
            highlight.depth = 99999; // We want it above everything
            highlight.cornerSize = 7.0 / scene.scaleX;
            highlight.borderSize = 1.0 / scene.scaleX;
            entity.add(highlight);

            app.onUpdate(this, update);

        });

    } //init

    function update(_) {

        highlight.size(entity.width / entity.scaleX, entity.height / entity.scaleY);
        highlight.cornerSize = 7.0 / scene.scaleX;
        highlight.borderSize = 1.0 / scene.scaleX;

    } //update

    function destroy() {

        trace('EDITABLE DESTROYED');

    } //destroy

} //Editable

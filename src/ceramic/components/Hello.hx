package ceramic.components;

import ceramic.App;
import ceramic.Sprite;

class Hello extends Component {

    var entity:App;

    function init() {

        screen.onUpdate(update);

    } //init

    function update(delta:Float):Void {

        // Do something at every frame

    } //update

    function destroy() {

        screen.offUpdate(update);

    } //destroy

}

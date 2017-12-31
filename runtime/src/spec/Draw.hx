package spec;

import backend.VisualItem;

interface Draw {

    function draw(visuals:Array<ceramic.Visual>):Void;

    function getItem(visual:ceramic.Visual):VisualItem;

} //Draw

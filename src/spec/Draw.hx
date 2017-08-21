package spec;

import backend.Draw;

interface Draw {

    function draw(visuals:Array<ceramic.Visual>):Void;

    function getItem(visual:ceramic.Visual):VisualItem;

} //Draw

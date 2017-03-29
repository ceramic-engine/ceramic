package spec;

import backend.Draw;

interface Draw {

    function draw(visuals:Array<ceramic.Visual>):Void;

    function drawKind(visual:ceramic.Visual):DrawKind;

} //Draw

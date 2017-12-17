package spec;

#if !completion
import backend.Draw;
#else
typedef VisualItem = Dynamic;
#end

interface Draw {

    function draw(visuals:Array<ceramic.Visual>):Void;

    function getItem(visual:ceramic.Visual):VisualItem;

} //Draw

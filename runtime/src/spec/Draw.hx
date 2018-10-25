package spec;

import backend.VisualItem;

interface Draw {

    function draw(visuals:Array<ceramic.Visual>):Void;

    function stamp(visuals:Array<ceramic.Visual>, renderTexture:ceramic.RenderTexture, clear:Bool, clipX:Float, clipY:Float, clipWidth:Float, clipHeight:Float):Void;

    function getItem(visual:ceramic.Visual):VisualItem;

    function transformForRenderTarget(matrix:ceramic.Transform, renderTarget:ceramic.RenderTexture):Void;

} //Draw

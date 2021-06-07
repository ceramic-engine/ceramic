package ceramic;

import tracker.Model;

class SpriteSheetFrame extends Model {

    @serialize public var x:Int = 0;

    @serialize public var y:Int = 0;

    @serialize public var width:Int = 0;

    @serialize public var height:Int = 0;

    @serialize public var rotated:Bool = false;

    @serialize public var trimmed:Bool = false;

    @serialize public var trimX:Int = 0;

    @serialize public var trimY:Int = 0;

    @serialize public var trimWidth:Int = 0;

    @serialize public var trimHeight:Int = 0;

    @serialize public var duration:Float = 0;

/// Helpers

    inline public function frame(frameX:Int, frameY:Int, frameWidth:Int, frameHeight:Int):Void {

        this.x = frameX;
        this.y = frameY;
        this.width = frameWidth;
        this.height = frameHeight;

    }

}

package ceramic;

import tracker.Model;

using ceramic.Extensions;

class SpriteSheetAnimation extends Model {

    @serialize public var name:String = null;

    @serialize public var frames:ReadOnlyArray<SpriteSheetFrame> = null;

    @compute public function duration():Float {

        var result:Float = 0.0;

        var frames = this.frames;
        if (frames != null) {
            for (i in 0...frames.length) {
                result += frames.unsafeGet(i).duration;
            }
        }

        return result;

    }

}

package ceramic;

import tracker.Model;

class SpriteSheetAnimation extends Model {

    @serialize public var name:String = null;

    @serialize public var frames:ReadOnlyArray<SpriteSheetFrame> = null;

}

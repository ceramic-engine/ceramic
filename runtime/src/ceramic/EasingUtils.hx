package ceramic;

class EasingUtils {

    static var _emptyArray:Array<Dynamic> = [];

    public static function easingFromString(str:String):Easing {

        return Type.createEnum(Easing, str, _emptyArray);

    }

}

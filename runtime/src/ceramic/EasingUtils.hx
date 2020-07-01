package ceramic;

class EasingUtils {

    static var _emptyArray:Array<Dynamic> = [];

    public static function easingFromString(str:String):Easing {

        // TODO BEZIER

        return Type.createEnum(Easing, str, _emptyArray);

    }

    public static function easingToString(easing:Easing):String {

        // TODO BEZIER

        return easing.getName();

    }

}

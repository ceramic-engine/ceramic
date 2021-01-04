package clay;

class Log {

    public static function debug(message:String):Void {

        #if clay_debug
        trace('[debug] ' + message);
        #end

    }

    public static function info(message:String):Void {

        trace('[info] ' + message);

    }

    public static function warning(message:String):Void {

        trace('[warning] ' + message);

    }

    public static function error(message:String):Void {

        trace('[error] ' + message);

    }

    public static function success(message:String):Void {

        trace('[success] ' + message);

    }

}

package tools;

import tools.Helpers.*;

class Colors {

    public static function black(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[30m" + str + "\u001b[0m";
        }
    }

    public static function red(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[31m" + str + "\u001b[0m";
        }
    }

    public static function green(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[32m" + str + "\u001b[0m";
        }
    }

    public static function yellow(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[33m" + str + "\u001b[0m";
        }
    }

    public static function blue(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[34m" + str + "\u001b[0m";
        }
    }

    public static function magenta(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[35m" + str + "\u001b[0m";
        }
    }

    public static function cyan(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[36m" + str + "\u001b[0m";
        }
    }

    public static function white(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[37m" + str + "\u001b[0m";
        }
    }

    public static function gray(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[90m" + str + "\u001b[0m";
        }
    }

    public static function grey(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[90m" + str + "\u001b[0m";
        }
    }

    public static function bgBlack(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[40m" + str + "\u001b[0m";
        }
    }

    public static function bgRed(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[41m" + str + "\u001b[0m";
        }
    }

    public static function bgGreen(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[42m" + str + "\u001b[0m";
        }
    }

    public static function bgYellow(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[43m" + str + "\u001b[0m";
        }
    }

    public static function bgBlue(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[44m" + str + "\u001b[0m";
        }
    }

    public static function bgMagenta(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[45m" + str + "\u001b[0m";
        }
    }

    public static function bgCyan(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[46m" + str + "\u001b[0m";
        }
    }

    public static function bgWhite(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[47m" + str + "\u001b[0m";
        }
    }

    public static function reset(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[0m" + str + "\u001b[0m";
        }
    }

    public static function bold(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[1m" + str + "\u001b[0m";
        }
    }

    public static function dim(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[2m" + str + "\u001b[0m";
        }
    }

    public static function italic(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[3m" + str + "\u001b[0m";
        }
    }

    public static function underline(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[4m" + str + "\u001b[0m";
        }
    }

    public static function inverse(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[7m" + str + "\u001b[0m";
        }
    }

    public static function hidden(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[8m" + str + "\u001b[0m";
        }
    }

    public static function strikethrough(str:String):String {
        if (!context.colors) {
            return str;
        } else {
            return "\u001b[9m" + str + "\u001b[0m";
        }
    }

}
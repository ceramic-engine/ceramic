package tools;

import tools.Helpers.*;

class Colors {

    public static function black(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:black|]' + str + '[|/color:black|]';
        } else {
            return npm.Colors.black(str);
        }
    }
    public static function red(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:red|]' + str + '[|/color:red|]';
        } else {
            return npm.Colors.red(str);
        }
    }
    public static function green(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:green|]' + str + '[|/color:green|]';
        } else {
            return npm.Colors.green(str);
        }
    }
    public static function yellow(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:yellow|]' + str + '[|/color:yellow|]';
        } else {
            return npm.Colors.yellow(str);
        }
    }
    public static function blue(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:blue|]' + str + '[|/color:blue|]';
        } else {
            return npm.Colors.blue(str);
        }
    }
    public static function magenta(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:magenta|]' + str + '[|/color:magenta|]';
        } else {
            return npm.Colors.magenta(str);
        }
    }
    public static function cyan(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:cyan|]' + str + '[|/color:cyan|]';
        } else {
            return npm.Colors.cyan(str);
        }
    }
    public static function white(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:white|]' + str + '[|/color:white|]';
        } else {
            return npm.Colors.white(str);
        }
    }
    public static function gray(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:gray|]' + str + '[|/color:gray|]';
        } else {
            return npm.Colors.gray(str);
        }
    }
    public static function grey(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:grey|]' + str + '[|/color:grey|]';
        } else {
            return npm.Colors.grey(str);
        }
    }

    public static function bgBlack(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgBlack|]' + str + '[|/color:bgBlack|]';
        } else {
            return npm.Colors.bgBlack(str);
        }
    }
    public static function bgRed(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgRed|]' + str + '[|/color:bgRed|]';
        } else {
            return npm.Colors.bgRed(str);
        }
    }
    public static function bgGreen(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgGreen|]' + str + '[|/color:bgGreen|]';
        } else {
            return npm.Colors.bgGreen(str);
        }
    }
    public static function bgYellow(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgYellow|]' + str + '[|/color:bgYellow|]';
        } else {
            return npm.Colors.bgYellow(str);
        }
    }
    public static function bgBlue(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgBlue|]' + str + '[|/color:bgBlue|]';
        } else {
            return npm.Colors.bgBlue(str);
        }
    }
    public static function bgMagenta(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgMagenta|]' + str + '[|/color:bgMagenta|]';
        } else {
            return npm.Colors.bgMagenta(str);
        }
    }
    public static function bgCyan(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgCyan|]' + str + '[|/color:bgCyan|]';
        } else {
            return npm.Colors.bgCyan(str);
        }
    }
    public static function bgWhite(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bgWhite|]' + str + '[|/color:bgWhite|]';
        } else {
            return npm.Colors.bgWhite(str);
        }
    }

    public static function reset(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:reset|]' + str + '[|/color:reset|]';
        } else {
            return npm.Colors.reset(str);
        }
    }
    public static function bold(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:bold|]' + str + '[|/color:bold|]';
        } else {
            return npm.Colors.bold(str);
        }
    }
    public static function dim(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:dim|]' + str + '[|/color:bladimck|]';
        } else {
            return npm.Colors.dim(str);
        }
    }
    public static function italic(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:italic|]' + str + '[|/color:italic|]';
        } else {
            return npm.Colors.italic(str);
        }
    }
    public static function underline(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:underline|]' + str + '[|/color:underline|]';
        } else {
            return npm.Colors.underline(str);
        }
    }
    public static function inverse(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:inverse|]' + str + '[|/color:inverse|]';
        } else {
            return npm.Colors.inverse(str);
        }
    }
    public static function hidden(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:hidden|]' + str + '[|/color:hidden|]';
        } else {
            return npm.Colors.hidden(str);
        }
    }
    public static function strikethrough(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:strikethrough|]' + str + '[|/color:strikethrough|]';
        } else {
            return npm.Colors.strikethrough(str);
        }
    }

    public static function rainbow(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:rainbow|]' + str + '[|/color:rainbow|]';
        } else {
            return npm.Colors.rainbow(str);
        }
    }
    public static function zebra(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:zebra|]' + str + '[|/color:zebra|]';
        } else {
            return npm.Colors.zebra(str);
        }
    }
    public static function america(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:america|]' + str + '[|/color:america|]';
        } else {
            return npm.Colors.america(str);
        }
    }
    public static function trap(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:trap|]' + str + '[|/color:trap|]';
        } else {
            return npm.Colors.trap(str);
        }
    }
    public static function random(str:String):String {
        if (!context.colors) {
            return str;
        } else if (isElectronProxy()) {
            return '[|color:random|]' + str + '[|/color:random|]';
        } else {
            return npm.Colors.random(str);
        }
    }

}

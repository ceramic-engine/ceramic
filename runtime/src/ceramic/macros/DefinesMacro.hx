package ceramic.macros;

/**
 * Utilities to access compile-time defines from code.
 * This class provides macro functions to retrieve and parse compiler flags (defines)
 * at compile time, making them available as constants in the generated code.
 * 
 * Ceramic uses defines extensively for configuration values that need to be
 * embedded at compile time, such as asset paths, target-specific settings,
 * and feature flags.
 * 
 * Original source: https://code.haxe.org/category/macros/get-compiler-define-value.html
 */
class DefinesMacro {

    /**
     * Retrieves a compiler flag value as a string.
     * The value is embedded as a constant in the generated code.
     * 
     * Example:
     * ```haxe
     * var version = DefinesMacro.getDefine("app_version"); // "1.0.0"
     * ```
     * 
     * @param key The name of the compiler flag
     * @return Expression containing the flag value as a string
     */
    public static macro function getDefine(key:String):haxe.macro.Expr {
        return macro $v{haxe.macro.Context.definedValue(key)};
    }

    /**
     * Retrieves a compiler flag value that has been double-encoded as JSON.
     * Some Ceramic build tools encode values twice to ensure proper escaping
     * through multiple processing stages.
     * 
     * Example:
     * ```haxe
     * var paths = DefinesMacro.getJsonJsonDefine("ceramic_extra_assets_paths"); // ["path1", "path2"]
     * ```
     * 
     * @param key The name of the compiler flag
     * @return Expression containing the decoded value
     */
    public static macro function getJsonJsonDefine(key:String):haxe.macro.Expr {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? Json.parse(Json.parse(raw)) : null;
        return macro $v{value};
    }

    /**
     * Retrieves a compiler flag value that has been encoded as JSON.
     * Used for complex data structures passed through compiler flags.
     * 
     * Example:
     * ```haxe
     * var config = DefinesMacro.getJsonDefine("app_config"); // {debug: true, ...}
     * ```
     * 
     * @param key The name of the compiler flag
     * @return Expression containing the decoded value
     */
    public static macro function getJsonDefine(key:String):haxe.macro.Expr {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? Json.parse(raw) : null;
        return macro $v{value};
    }

    #if macro
    /**
     * Macro-context helper to decode double-JSON-encoded define values.
     * Used internally by other macros that need to process defines.
     * 
     * @param key The name of the compiler flag
     * @return Decoded value or null if not defined
     */
    public static function jsonJsonDefinedValue(key:String):String {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? haxe.Json.parse(haxe.Json.parse(raw)) : null;
        return value;
    }

    /**
     * Macro-context helper to decode JSON-encoded define values.
     * Used internally by other macros that need to process defines.
     * 
     * @param key The name of the compiler flag
     * @return Decoded value or null if not defined
     */
    public static function jsonDefinedValue(key:String):String {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? haxe.Json.parse(raw) : null;
        return value;
    }
    #end

    /**
     * Retrieves a compiler flag value and parses it as a Float.
     * 
     * Example:
     * ```haxe
     * var scale = DefinesMacro.getFloatDefine("ui_scale"); // 1.5
     * ```
     * 
     * @param key The name of the compiler flag
     * @return Expression containing the parsed float value
     */
    public static macro function getFloatDefine(key:String):haxe.macro.Expr {
        return macro $v{Std.parseFloat(haxe.macro.Context.definedValue(key))};
    }

    /**
     * Retrieves a compiler flag value and parses it as an Int.
     * 
     * Example:
     * ```haxe
     * var maxPlayers = DefinesMacro.getIntDefine("max_players"); // 4
     * ```
     * 
     * @param key The name of the compiler flag
     * @return Expression containing the parsed integer value
     */
    public static macro function getIntDefine(key:String):haxe.macro.Expr {
        return macro $v{Std.parseInt(haxe.macro.Context.definedValue(key))};
    }

    /**
     * Retrieves a compiler flag value and parses it as a Bool.
     * Recognizes "true", "1" as true, everything else as false.
     * 
     * Example:
     * ```haxe
     * var debugMode = DefinesMacro.getBoolDefine("debug_mode"); // true
     * ```
     * 
     * @param key The name of the compiler flag
     * @return Expression containing the parsed boolean value
     */
    public static macro function getBoolDefine(key:String):haxe.macro.Expr {
        return macro $v{_stringToBool(haxe.macro.Context.definedValue(key))};
    }

    /**
     * Helper function to convert string values to boolean.
     * @param str String to convert ("true" or "1" becomes true)
     * @return Boolean value
     */
    static function _stringToBool(str:String):Bool {

        if (str == null)
            return false;
        str = str.toLowerCase();
        return str == 'true' || str == '1';

    }

    /**
     * Checks if a compiler flag is defined (regardless of its value).
     * 
     * Example:
     * ```haxe
     * if (DefinesMacro.isDefined("ceramic_use_arcade")) {
     *     // Arcade physics is enabled
     * }
     * ```
     * 
     * @param key The name of the compiler flag
     * @return Expression containing true if defined, false otherwise
     */
    public static macro function isDefined(key:String):haxe.macro.Expr {
        return macro $v{haxe.macro.Context.defined(key)};
    }

    /**
     * Retrieves a map of all defined compiler flags and their values.
     * Useful for debugging or conditional compilation based on multiple flags.
     * 
     * Example:
     * ```haxe
     * var allDefines = DefinesMacro.getDefines();
     * for (key => value in allDefines) {
     *     trace('$key = $value');
     * }
     * ```
     * 
     * @return Expression containing a Map<String,String> of all defines
     */
    public static macro function getDefines():haxe.macro.Expr {
        var defines : Map<String, String> = haxe.macro.Context.getDefines();
        // Construct map syntax so we can return it as an expression
        var map : Array<haxe.macro.Expr> = [];
        for (key in defines.keys()) {
            map.push(macro $v{key} => $v{Std.string(defines.get(key))});
        }
        return macro $a{map};
    }

}

package ceramic;

/**
 * The kind of virtual keyboard a platform shows for the edited text, chosen
 * from the settings of `ceramic.Input.setTextEditingConfiguration()` (the
 * HTML `inputmode` and `enterkeyhint` values). Backends with a native
 * virtual keyboard map it to theirs (Unity: `TouchScreenKeyboardType`).
 */
enum abstract VirtualKeyboardType(Int) from Int to Int {

    /** No virtual keyboard (`inputmode` `none`). */
    var NONE = 0;

    /** Text. */
    var DEFAULT = 1;

    /** Digits only (`numeric`). */
    var NUMBER_PAD = 2;

    /** Digits and a decimal separator (`decimal`). */
    var DECIMAL_PAD = 3;

    /** Telephone number (`tel`). */
    var PHONE_PAD = 4;

    /** Email address (`email`). */
    var EMAIL = 5;

    /** URL (`url`). */
    var URL = 6;

    /** Search terms (`search`, or text with the `search` enter key hint). */
    var SEARCH = 7;

    /**
     * The keyboard for an `inputmode` and `enterkeyhint` pair. Unknown modes
     * give `DEFAULT`.
     */
    public static function fromConfiguration(inputMode:String, enterKeyHint:Null<String>):VirtualKeyboardType {

        return switch inputMode {
            case 'none': NONE;
            case 'numeric': NUMBER_PAD;
            case 'decimal': DECIMAL_PAD;
            case 'tel': PHONE_PAD;
            case 'email': EMAIL;
            case 'url': URL;
            case 'search': SEARCH;
            case _: enterKeyHint == 'search' ? SEARCH : DEFAULT;
        }

    }

    /**
     * Whether the return key of the keyboard inserts line breaks (no enter
     * key hint, or `enter`): the keyboard stays open and each line break is
     * an enter key. Otherwise (`done`, `go`, `next`, `previous`, `search`,
     * `send`) it is a single line keyboard whose return key closes it.
     */
    public static function multilineFromConfiguration(enterKeyHint:Null<String>):Bool {

        return enterKeyHint == null || enterKeyHint == 'enter';

    }

    public function toString():String {

        return switch (cast this:VirtualKeyboardType) {
            case NONE: 'NONE';
            case DEFAULT: 'DEFAULT';
            case NUMBER_PAD: 'NUMBER_PAD';
            case DECIMAL_PAD: 'DECIMAL_PAD';
            case PHONE_PAD: 'PHONE_PAD';
            case EMAIL: 'EMAIL';
            case URL: 'URL';
            case SEARCH: 'SEARCH';
            case _: 'VirtualKeyboardType(' + this + ')';
        }

    }

}

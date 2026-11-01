// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Platform text-assistance preferences for the focused text region.
 *
 * Returned by `InputHandler.textInputConfiguration` and forwarded to the
 * platform whenever it changes (`PlatformTextInput.setTextInputConfiguration`).
 *
 * The default disables all text assistance and requests no particular action
 * key presentation. Compare with `equals()`.
 */
class TextInputConfiguration {

    /** Whether the platform may automatically correct entered text. */
    public final autocorrect:Bool;

    /** How software keyboards automatically capitalize entered text. */
    public final autocapitalize:Autocapitalize;

    /** Whether software keyboards may offer word suggestions and spellcheck. */
    public final suggestions:Bool;

    /** The action advertised on a software keyboard's confirm ("enter") key. */
    public final inputAction:TextInputAction;

    public function new(autocorrect:Bool = false, ?autocapitalize:Autocapitalize, suggestions:Bool = false, ?inputAction:TextInputAction) {
        this.autocorrect = autocorrect;
        this.autocapitalize = autocapitalize != null ? autocapitalize : Autocapitalize.None;
        this.suggestions = suggestions;
        this.inputAction = inputAction != null ? inputAction : TextInputAction.Unspecified;
    }

    /** Rust `TextInputConfiguration::default()` */
    public static function defaultValue():TextInputConfiguration {
        return new TextInputConfiguration();
    }

    /** A copy with some fields replaced (Rust `TextInputConfiguration { ..other }`). */
    public function with(?autocorrect:Bool, ?autocapitalize:Autocapitalize, ?suggestions:Bool, ?inputAction:TextInputAction):TextInputConfiguration {
        return new TextInputConfiguration(
            autocorrect != null ? autocorrect : this.autocorrect,
            autocapitalize != null ? autocapitalize : this.autocapitalize,
            suggestions != null ? suggestions : this.suggestions,
            inputAction != null ? inputAction : this.inputAction
        );
    }

    public function equals(other:Null<TextInputConfiguration>):Bool {
        return other != null && autocorrect == other.autocorrect && autocapitalize == other.autocapitalize
            && suggestions == other.suggestions && inputAction == other.inputAction;
    }

    public function toString():String {
        return 'TextInputConfiguration(autocorrect: $autocorrect, autocapitalize: $autocapitalize, suggestions: $suggestions, inputAction: $inputAction)';
    }

}

/**
 * Automatic capitalization applied by software keyboards.
 */
enum abstract Autocapitalize(Int) {

    /** No automatic capitalization. */
    var None = 0;

    /** Capitalize the first letter of each word. */
    var Words = 1;

    /** Capitalize the first letter of each sentence. */
    var Sentences = 2;

    /** Capitalize every letter. */
    var Characters = 3;

}

/**
 * The action a software keyboard advertises on its confirm ("enter") key.
 * This affects only how the key is presented; pressing it is still delivered
 * as ordinary input. `Unspecified` means "emit no hint".
 */
enum abstract TextInputAction(Int) {

    /** Let the platform choose its default presentation. */
    var Unspecified = 0;

    /** Inserting a line break. */
    var Enter = 1;

    /** Committing the field's value. */
    var Done = 2;

    /** Navigating to the typed target. */
    var Go = 3;

    /** Moving to the next field. */
    var Next = 4;

    /** Moving to the previous field. */
    var Previous = 5;

    /** Executing a search. */
    var Search = 6;

    /** Sending a message. */
    var Send = 7;

}

// Ported from vscode src/vs/platform/configuration/common/configuration.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.configuration.common;

import cityscape.base.common.Event;

/**
 * A key and its value, for `updateValues` (Monaco's `[string, any]`).
 */
typedef ConfigurationValue = {
    var key:String;
    var value:Any;
}

/**
 * The configuration of a `Cityscape` context (Monaco's
 * `IConfigurationService`), reduced to what the standalone editor uses:
 * settings without resource or language overrides.
 */
interface IConfigurationService {

    /**
     * Fired when values change.
     */
    var onDidChangeConfiguration(get, never):Event<ConfigurationChangeEvent>;

    /**
     * The value of a setting (`editor.tabSize`), or the object of the
     * settings under a section (`editor`: `{tabSize: 2, ...}`), null when
     * nothing is set there.
     */
    function getValue(section:String):Any;

    /**
     * Sets values (Monaco's `updateValues`); fires one change event for the
     * keys whose value changed.
     */
    function updateValues(values:Array<ConfigurationValue>):Void;

}

/**
 * The keys a change touched (Monaco's `IConfigurationChangeEvent`).
 */
class ConfigurationChangeEvent {

    public final affectedKeys:Array<String>;

    public function new(affectedKeys:Array<String>) {
        this.affectedKeys = affectedKeys;
    }

    /**
     * Whether the change touches `section` or a setting under it
     * (`affectsConfiguration('editor')` for `editor.tabSize`), or a section
     * holding it.
     */
    public function affectsConfiguration(section:String):Bool {
        for (key in affectedKeys) {
            if (key == section || StringTools.startsWith(key, section + '.') || StringTools.startsWith(section, key + '.')) {
                return true;
            }
        }
        return false;
    }

}

// Ported from vscode src/vs/editor/common/core/characterClassifier.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import haxe.ds.IntMap;
import haxe.io.Bytes;

/**
 * A fast character classifier that uses a compact array for ASCII values.
 * Values are numbers from 0 to 255 (`toUint8`).
 */
class CharacterClassifier {

    /**
     * Maintain a compact (fully initialized ASCII map for quickly classifying ASCII characters - used more often in code).
     */
    final _asciiMap:Bytes;

    /**
     * The entire map (sparse array).
     */
    final _map:IntMap<Int>;

    final _defaultValue:Int;

    public function new(_defaultValue:Int) {
        final defaultValue = toUint8(_defaultValue);

        this._defaultValue = defaultValue;
        this._asciiMap = CharacterClassifier._createAsciiMap(defaultValue);
        this._map = new IntMap<Int>();
    }

    static inline function toUint8(v:Int):Int {
        if (v < 0) {
            return 0;
        }
        if (v > 255) {
            return 255;
        }
        return v;
    }

    static function _createAsciiMap(defaultValue:Int):Bytes {
        final asciiMap = Bytes.alloc(256);
        asciiMap.fill(0, 256, defaultValue);
        return asciiMap;
    }

    public function set(charCode:Int, _value:Int):Void {
        final value = toUint8(_value);

        if (charCode >= 0 && charCode < 256) {
            this._asciiMap.set(charCode, value);
        }
        else {
            this._map.set(charCode, value);
        }
    }

    public function get(charCode:Int):Int {
        if (charCode >= 0 && charCode < 256) {
            return this._asciiMap.get(charCode);
        }
        else {
            final v = this._map.get(charCode);
            // `this._map.get(charCode) || this._defaultValue`
            return (v == null || v == 0) ? this._defaultValue : v;
        }
    }

    public function clear():Void {
        this._asciiMap.fill(0, 256, this._defaultValue);
        this._map.clear();
    }

}

class CharacterSet {

    final _actual:CharacterClassifier;

    public function new() {
        this._actual = new CharacterClassifier(0);
    }

    public function add(charCode:Int):Void {
        this._actual.set(charCode, 1);
    }

    public function has(charCode:Int):Bool {
        return (this._actual.get(charCode) == 1);
    }

    public function clear():Void {
        this._actual.clear();
    }

}

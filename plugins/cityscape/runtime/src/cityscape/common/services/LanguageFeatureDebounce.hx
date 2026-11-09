// Ported from vscode src/vs/editor/common/services/languageFeatureDebounce.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.common.Model.ITextModel;

/**
 * Monaco's `FeatureDebounceInformation` (`ILanguageFeatureDebounceService.for(
 * registry, name, {min, max})`): the delay of a feature follows the time
 * its last computations took on a model (a sliding average of 6), clamped
 * between `min` and `max` (`min²` by default), `min × 1.5` before any
 * (the average of the models when some were measured). Monaco keeps one
 * per registry in a global service keyed by the model and its providers;
 * here each contribution keeps its own, keyed by the model id.
 */
class FeatureDebounceInformation implements IFeatureDebounceInformation {

    final _min:Float;
    final _max:Float;
    final _default:Float;
    final _cache:Map<String, SlidingWindowAverage> = new Map();
    final _keys:Array<String> = [];

    public function new(min:Float = 50, ?max:Float) {
        this._min = min;
        this._max = max != null ? max : min * min;
        this._default = min * 1.5;
    }

    function clamp(value:Float):Float {
        return Math.min(_max, Math.max(_min, value));
    }

    public function get(model:ITextModel):Float {
        final avg = _cache.get(model.id);
        return avg != null ? clamp(avg.value) : this.defaultValue();
    }

    public function update(model:ITextModel, value:Float):Float {
        final key = model.id;
        var avg = _cache.get(key);
        if (avg == null) {
            avg = new SlidingWindowAverage(6);
            _cache.set(key, avg);
            _keys.push(key);
            // LRUCache(50)
            if (_keys.length > 50) {
                _cache.remove(_keys.shift());
            }
        }
        return clamp(avg.update(value));
    }

    function _overall():Float {
        // MovingAverage of the averages
        var n = 0;
        var value = 0.0;
        for (key in _keys) {
            final avg = _cache.get(key);
            n++;
            value = value + (avg.value - value) / n;
        }
        return value;
    }

    /**
     * Monaco's `default()`.
     */
    public function getDefault():Float {
        return defaultValue();
    }

    public function defaultValue():Float {
        final overall = Std.int(_overall());
        final value = overall != 0 ? overall : _default;
        return clamp(value);
    }

}

/**
 * Monaco's `SlidingWindowAverage` (numbers.ts).
 */
class SlidingWindowAverage {

    var _n:Int = 0;
    var _val:Float = 0;
    final _values:Array<Float> = [];
    var _index:Int = 0;
    var _sum:Float = 0;

    public function new(size:Int) {
        for (i in 0...size) {
            _values.push(0);
        }
    }

    public function update(value:Float):Float {
        final oldValue = this._values[this._index];
        this._values[this._index] = value;
        this._index = (this._index + 1) % this._values.length;

        this._sum -= oldValue;
        this._sum += value;

        if (this._n < this._values.length) {
            this._n += 1;
        }

        this._val = this._sum / this._n;
        return this._val;
    }

    public var value(get, never):Float;
    function get_value():Float {
        return this._val;
    }

}

/*
 * Only the interface and `NullDebounceInformation` are ported so far (the
 * inline completions use a debounce clamped to [50, 50] ms, which is always
 * 50 ms in Monaco's `FeatureDebounceInformation`). The sliding averages per
 * model of `LanguageFeatureDebounceService` are not ported yet.
 */

interface IFeatureDebounceInformation {
    function get(model:ITextModel):Float;
    function update(model:ITextModel, value:Float):Float;
    function getDefault():Float;
}

/**
 * A debounce that is always `_default` (Monaco's `NullDebounceInformation`;
 * `default()` is `getDefault()`, `default` being a Haxe keyword).
 */
class NullDebounceInformation implements IFeatureDebounceInformation {

    final _default:Float;

    public function new(defaultValue:Float) {
        this._default = defaultValue;
    }

    public function get(_model:ITextModel):Float {
        return this._default;
    }

    public function update(_model:ITextModel, _value:Float):Float {
        return this._default;
    }

    public function getDefault():Float {
        return this._default;
    }

}

// Ported from vscode src/vs/editor/common/model/fixedArray.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

/**
 * An array that avoids being sparse by always
 * filling up unused indices with a default value.
 */
class FixedArray<T> {

    var _store:Array<T> = [];

    final _default:T;

    public function new(defaultValue:T) {
        _default = defaultValue;
    }

    public function get(index:Int):T {
        if (index < _store.length) {
            return _store[index];
        }
        return _default;
    }

    public function set(index:Int, value:T):Void {
        while (index >= _store.length) {
            _store[_store.length] = _default;
        }
        _store[index] = value;
    }

    public function replace(index:Int, oldLength:Int, newLength:Int):Void {
        if (index >= _store.length) {
            return;
        }

        if (oldLength == 0) {
            insert(index, newLength);
            return;
        }
        else if (newLength == 0) {
            delete(index, oldLength);
            return;
        }

        final before = _store.slice(0, index);
        final after = _store.slice(index + oldLength);
        final insertArr = arrayFill(newLength, _default);
        _store = before.concat(insertArr).concat(after);
    }

    public function delete(deleteIndex:Int, deleteCount:Int):Void {
        if (deleteCount == 0 || deleteIndex >= _store.length) {
            return;
        }
        _store.splice(deleteIndex, deleteCount);
    }

    public function insert(insertIndex:Int, insertCount:Int):Void {
        if (insertCount == 0 || insertIndex >= _store.length) {
            return;
        }
        final arr:Array<T> = [];
        for (i in 0...insertCount) {
            arr[i] = _default;
        }
        _store = cityscape.base.common.Arrays.arrayInsert(_store, insertIndex, arr);
    }

    static function arrayFill<T>(length:Int, value:T):Array<T> {
        final arr:Array<T> = [];
        for (i in 0...length) {
            arr[i] = value;
        }
        return arr;
    }

}

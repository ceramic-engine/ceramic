// New code for Cityscape (not a port): the part of vscode's storage service
// (src/vs/platform/storage/common/storage.ts, not in the reference clone)
// that the editor contributions use, kept in memory.
package cityscape.platform.storage.common;

/**
 * Where a value is stored (vscode's `StorageScope`).
 */
enum abstract StorageScope(Int) from Int to Int {
    /**
     * The stored data will be scoped to all workspaces across all profiles.
     */
    var APPLICATION = -1;
    /**
     * The stored data will be scoped to all workspaces of the same profile.
     */
    var PROFILE = 0;
    /**
     * The stored data will be scoped to the current workspace.
     */
    var WORKSPACE = 1;
}

/**
 * Who the value is for (vscode's `StorageTarget`): kept for the API, the
 * in-memory storage does not sync anything.
 */
enum abstract StorageTarget(Int) from Int to Int {
    var USER = 0;
    var MACHINE = 1;
}

/**
 * The storage service of a `Cityscape` context (vscode's `IStorageService`,
 * the booleans and strings the contributions use).
 */
interface IStorageService {

    function getBoolean(key:String, scope:StorageScope, ?fallbackValue:Bool):Null<Bool>;

    function get(key:String, scope:StorageScope, ?fallbackValue:String):Null<String>;

    /**
     * Stores a value (a `Bool`, a number or a string, kept as a string like
     * vscode does). Null removes the key.
     */
    function store(key:String, value:Any, scope:StorageScope, target:StorageTarget):Void;

    function remove(key:String, scope:StorageScope):Void;

}

/**
 * A storage kept in memory for the life of the context (vscode's
 * `InMemoryStorageService`). The host can replace it to persist the options
 * of the find widget and the like.
 */
class InMemoryStorageService implements IStorageService {

    final _values:Map<String, String> = new Map();

    public function new() {}

    static inline function key(key:String, scope:StorageScope):String {
        return (scope : Int) + ':' + key;
    }

    public function get(key:String, scope:StorageScope, ?fallbackValue:String):Null<String> {
        final value = _values.get(InMemoryStorageService.key(key, scope));
        return value != null ? value : fallbackValue;
    }

    public function getBoolean(key:String, scope:StorageScope, ?fallbackValue:Bool):Null<Bool> {
        final value = _values.get(InMemoryStorageService.key(key, scope));
        if (value == null) {
            return fallbackValue;
        }
        return value == 'true';
    }

    public function store(key:String, value:Any, scope:StorageScope, target:StorageTarget):Void {
        if (value == null) {
            remove(key, scope);
            return;
        }
        _values.set(InMemoryStorageService.key(key, scope), Std.string(value));
    }

    public function remove(key:String, scope:StorageScope):Void {
        _values.remove(InMemoryStorageService.key(key, scope));
    }

}

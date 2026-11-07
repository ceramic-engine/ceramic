// Ported from gpui-pre 0.3.10: src/action.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Error thrown by `ActionRegistry.buildAction` / `App.buildAction`.
 *
 * Rust's enum (`NotFound { name }`, `BuildError { name, error }`) becomes one
 * exception class: `error` is null for `NotFound`.
 */
class ActionBuildError extends haxe.Exception {

    /**
     * Name of the action that was not found or failed to build.
     */
    public final actionName:String;

    /**
     * Error that occurred while building the action, typically a JSON
     * deserialization error. Null when the action was not found.
     */
    public final error:Null<haxe.Exception>;

    function new(actionName:String, error:Null<haxe.Exception>) {
        super(error == null
            ? 'Didn\'t find an action named "$actionName"'
            : 'Error while building action "$actionName": ' + error.message
        );
        this.actionName = actionName;
        this.error = error;
    }

    /**
     * Indicates that an action with this name has not been registered.
     */
    public static function notFound(name:String):ActionBuildError {
        return new ActionBuildError(name, null);
    }

    /**
     * Indicates that an error occurred while building the action.
     */
    public static function buildError(name:String, error:haxe.Exception):ActionBuildError {
        return new ActionBuildError(name, error);
    }

    public inline function isNotFound():Bool {
        return error == null;
    }

}

// Ported from gpui-pre 0.3.10: src/inspector.rs (`inspector_reflection::FunctionReflection`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Reification of a function that has the signature `fn some_fn(T) -> T`. Provides the name,
 * documentation, and ability to invoke the function.
 *
 * Built by the tables of `#[derive_inspector_reflection]` (`StyledReflection`,
 * `gpui.base.StyledExtReflection`). Rust stores a type erased function
 * pointer; here the table gives its dispatch function and the method's index.
 */
class FunctionReflection<T> {

    /** The name of the function */
    public final name:String;

    /** Documentation for the function */
    public final documentation:Null<String>;

    final index:Int;

    final dispatch:(Int, T) -> T;

    public function new(name:String, documentation:Null<String>, index:Int, dispatch:(Int, T) -> T) {
        this.name = name;
        this.documentation = documentation;
        this.index = index;
        this.dispatch = dispatch;
    }

    /**
     * Invoke this method on a value and return the result. Style methods
     * modify the refinement they are given and return it, like the Rust
     * builder methods consume and return `self`.
     */
    public inline function invoke(value:T):T {
        return dispatch(index, value);
    }

}

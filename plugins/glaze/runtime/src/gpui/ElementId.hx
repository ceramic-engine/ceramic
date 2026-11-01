// Ported from gpui-pre 0.3.10: src/window.rs (`ElementId`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An identifier for an element, used to retrieve its state across frames.
 * Only the variants used so far are ported (focus handles and paths come later).
 */
enum ElementId {

    /** The ID of a View element */
    View(entityId:Int);

    /** An integer ID. */
    Integer(id:Int);

    /** A string based ID. */
    Name(name:String);

    /** A combination of a name and an integer. */
    NamedInteger(name:String, id:Int);

    /** A code location (Rust `#[track_caller]`, Haxe `PosInfos`). */
    CodeLocation(file:String, line:Int);

    /** A name scoped to a parent id (Rust `NamedChild`, built from `(ElementId, &str)`). */
    NamedChild(parent:ElementId, name:String);

}

// Ported from gpui-pre 0.3.10: src/inspector.rs (`InspectorElementId`, `InspectorElementPath`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

#if glaze_inspector

/**
 * `GlobalElementId` qualified by source location of element construction.
 *
 * Rust keeps a `&'static Location` (file, line and column, from
 * `#[track_caller]`); the port keeps the `haxe.PosInfos` of the call that
 * built the element (file and line, Haxe has no column).
 */
class InspectorElementPath {

    /** The path to the nearest ancestor element that has an `ElementId`. */
    public final globalId:GlobalElementId;

    /** Source location where this element was constructed. */
    public final sourceLocation:haxe.PosInfos;

    /** Unique string key of the path (Rust hashes it). */
    public final key:String;

    public function new(globalId:GlobalElementId, sourceLocation:haxe.PosInfos) {
        this.globalId = globalId;
        this.sourceLocation = sourceLocation;
        this.key = globalId.key + '|' + formatLocation(sourceLocation);
    }

    /**
     * Rust `Display` of a `Location` (`file:line:column`): `file:line` here.
     */
    public static function formatLocation(location:haxe.PosInfos):String {
        return locationFormatter != null ? locationFormatter(location) : location.fileName + ':' + location.lineNumber;
    }

    /**
     * Replaces `formatLocation` (`fileName` is the path the compiler was
     * given, absolute with Ceramic's class paths): an app or a test harness
     * can show its files relative to its own root, like rustc does for the
     * crates of a workspace.
     */
    public static var locationFormatter:Null<(haxe.PosInfos) -> String> = null;

    public inline function equals(other:Null<InspectorElementPath>):Bool {
        return other != null && key == other.key;
    }

}

/**
 * A unique identifier for an element that can be inspected.
 */
class InspectorElementId {

    /** Stable part of the ID. */
    public final path:InspectorElementPath;

    /** Disambiguates elements that have the same path. */
    public final instanceId:Int;

    public function new(path:InspectorElementPath, instanceId:Int) {
        this.path = path;
        this.instanceId = instanceId;
    }

    /** Structural equality (Rust `#[derive(PartialEq)]`). */
    public function equals(other:Null<InspectorElementId>):Bool {
        return other != null && instanceId == other.instanceId && path.equals(other.path);
    }

    /** Unique string key of the id (Rust hashes it). */
    public inline function key():String {
        return path.key + '#' + instanceId;
    }

}

#end

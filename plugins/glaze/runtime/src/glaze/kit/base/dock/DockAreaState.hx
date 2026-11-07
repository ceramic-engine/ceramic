// Ported from gpui-kit 0.8.1: crates/base/src/dock/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.kit.base.dock.JsonValue;

using glaze.kit.base.dock.JsonValue.JsonValueTools;

/**
 * Used to serialize and deserialize the DockArea.
 *
 * This mirrors a persisted, on-disk schema shipped to end users. Its fields
 * stay public rather than following the seam's builder/reader convention.
 * The JSON is the one serde writes and reads (`toJson`, `fromJson`): field
 * order, the `null` version, the omitted docks and the `f32` number format
 * are the original's.
 */
class DockAreaState {

    /**
     * The version is used to mark this persisted state is compatible with the current version
     * For example, some times we many totally changed the structure of the Panel,
     * then we can compare the version to decide whether we can use the state or ignore.
     */
    public var version:Null<Int>;

    public var center:PanelState;

    public var leftDock:Null<DockState>;

    public var rightDock:Null<DockState>;

    public var bottomDock:Null<DockState>;

    public function new(?version:Int, ?center:PanelState, ?leftDock:DockState, ?rightDock:DockState, ?bottomDock:DockState) {
        this.version = version;
        this.center = center != null ? center : PanelState.defaultValue();
        this.leftDock = leftDock;
        this.rightDock = rightDock;
        this.bottomDock = bottomDock;
    }

    /**
     * Rust `DockAreaState::default()`.
     */
    public static function defaultValue():DockAreaState {
        return new DockAreaState();
    }

    public function clone():DockAreaState {
        return new DockAreaState(version, center.clone(), leftDock != null ? leftDock.clone() : null,
            rightDock != null ? rightDock.clone() : null, bottomDock != null ? bottomDock.clone() : null);
    }

    /**
     * Rust derived `PartialEq`.
     */
    public function equals(other:DockAreaState):Bool {
        return version == other.version && center.equals(other.center) && sameDock(leftDock, other.leftDock)
            && sameDock(rightDock, other.rightDock) && sameDock(bottomDock, other.bottomDock);
    }

    static function sameDock(a:Null<DockState>, b:Null<DockState>):Bool {
        return a == null ? b == null : (b != null && a.equals(b));
    }

    public function toJsonValue():JsonValue {
        final object = new JsonObject();
        object.set('version', version != null ? JInt(version) : JNull);
        object.set('center', center.toJsonValue());
        // `skip_serializing_if = "Option::is_none"`: omitted, not nulled
        if (leftDock != null) object.set('left_dock', leftDock.toJsonValue());
        if (rightDock != null) object.set('right_dock', rightDock.toJsonValue());
        if (bottomDock != null) object.set('bottom_dock', bottomDock.toJsonValue());
        return JObject(object);
    }

    public static function fromJsonValue(value:JsonValue):DockAreaState {
        final object = DockStateJson.struct(value, 'struct DockAreaState');
        final version = switch object.get('version') {
            case null | JNull: null;
            case v: DockStateJson.usize(v);
        }
        final center = PanelState.fromJsonValue(DockStateJson.field(object, 'center'));
        return new DockAreaState(version, center, dock(object, 'left_dock'), dock(object, 'right_dock'), dock(object, 'bottom_dock'));
    }

    static function dock(object:JsonObject, name:String):Null<DockState> {
        return switch object.get(name) {
            case null | JNull: null;
            case v: DockState.fromJsonValue(v);
        }
    }

    /**
     * `serde_json::from_str::<DockAreaState>` (throws a `JsonError`).
     */
    public static function fromJson(text:String):DockAreaState {
        return fromJsonValue(JsonValueTools.parse(text));
    }

    /**
     * `serde_json::to_string`.
     */
    public function toJson():String {
        return toJsonValue().stringify();
    }

    /**
     * `serde_json::to_string_pretty`.
     */
    public function toJsonPretty():String {
        return toJsonValue().stringifyPretty();
    }

}

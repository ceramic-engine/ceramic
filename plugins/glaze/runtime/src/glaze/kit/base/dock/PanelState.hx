// Ported from gpui-kit 0.8.1: crates/base/src/dock/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.base.dock.JsonValue;

using gpui.base.dock.JsonValue.JsonValueTools;
using gpui.base.dock.PanelInfo.PanelInfoTools;

/**
 * Used to serialize and deserialize the DockerItem.
 *
 * This mirrors a persisted, on-disk schema shipped to end users. Its fields
 * stay public rather than following the seam's builder/reader convention.
 */
class PanelState {

    public var panelName:String;

    public var children:Array<PanelState>;

    public var info:PanelInfo;

    /**
     * Rust `PanelState { panel_name, children, info }`.
     */
    public function new(panelName:String, ?children:Array<PanelState>, ?info:PanelInfo) {
        this.panelName = panelName;
        this.children = children != null ? children : [];
        this.info = info != null ? info : PanelInfo.Panel(JNull);
    }

    /**
     * Rust `PanelState::default()`: an empty name, no children and
     * `PanelInfo::Panel(Value::Null)`.
     */
    public static function defaultValue():PanelState {
        return new PanelState('');
    }

    /**
     * Rust `PanelState::new`: a leaf state for a panel with the given name.
     */
    public static function named(panelName:String):PanelState {
        return new PanelState(panelName);
    }

    public function addChild(panel:PanelState):Void {
        children.push(panel);
    }

    /**
     * Rust derived `Clone`: a deep copy (the JSON payload is immutable).
     */
    public function clone():PanelState {
        return new PanelState(panelName, [for (child in children) child.clone()], switch info {
            case Stack(sizes, axis): PanelInfo.Stack(sizes.copy(), axis);
            case other: other;
        });
    }

    /**
     * Rust derived `PartialEq`.
     */
    public function equals(other:PanelState):Bool {
        if (panelName != other.panelName || children.length != other.children.length || !info.equals(other.info)) return false;
        for (i in 0...children.length) if (!children[i].equals(other.children[i])) return false;
        return true;
    }

    public function toJsonValue():JsonValue {
        final object = new JsonObject();
        object.set('panel_name', JString(panelName));
        object.set('children', JArray([for (child in children) child.toJsonValue()]));
        object.set('info', info.toJsonValue());
        return JObject(object);
    }

    public static function fromJsonValue(value:JsonValue):PanelState {
        final object = DockStateJson.struct(value, 'struct PanelState');
        final name = DockStateJson.string(DockStateJson.field(object, 'panel_name'));
        final children = [for (child in DockStateJson.array(DockStateJson.field(object, 'children'))) fromJsonValue(child)];
        final info = PanelInfoTools.fromJsonValue(DockStateJson.field(object, 'info'));
        return new PanelState(name, children, info);
    }

    /**
     * `serde_json::from_str::<PanelState>` (throws a `JsonError`).
     */
    public static function fromJson(text:String):PanelState {
        return fromJsonValue(JsonValueTools.parse(text));
    }

    /**
     * `serde_json::to_string`.
     */
    public function toJson():String {
        return toJsonValue().stringify();
    }

}

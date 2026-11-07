// Ported from gpui-kit 0.8.1: crates/base/src/dock/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Pixels;
import gpui.SpringMath;
import gpui.base.dock.JsonValue;

/**
 * Used to serialize and deserialize the Dock.
 */
class DockState {

    final panelValue:PanelState;

    final placementValue:DockPlacement;

    final sizeValue:Pixels;

    final openValue:Bool;

    public function new(panel:PanelState, placement:DockPlacement, size:Pixels, open:Bool) {
        this.panelValue = panel;
        this.placementValue = placement;
        this.sizeValue = size;
        this.openValue = open;
    }

    public inline function panel():PanelState {
        return panelValue;
    }

    public inline function placement():DockPlacement {
        return placementValue;
    }

    public inline function size():Pixels {
        return sizeValue;
    }

    public inline function open():Bool {
        return openValue;
    }

    public function clone():DockState {
        return new DockState(panelValue.clone(), placementValue, sizeValue, openValue);
    }

    public function equals(other:DockState):Bool {
        return panelValue.equals(other.panelValue) && placementValue == other.placementValue
            && SpringMath.f32(sizeValue) == SpringMath.f32(other.sizeValue) && openValue == other.openValue;
    }

    public function toJsonValue():JsonValue {
        final object = new JsonObject();
        object.set('panel', panelValue.toJsonValue());
        object.set('placement', JString(placementValue.serdeName()));
        object.set('size', JFloat32(sizeValue));
        object.set('open', JBool(openValue));
        return JObject(object);
    }

    public static function fromJsonValue(value:JsonValue):DockState {
        final object = DockStateJson.struct(value, 'struct DockState');
        final panel = PanelState.fromJsonValue(DockStateJson.field(object, 'panel'));
        final tag = DockStateJson.string(DockStateJson.field(object, 'placement'));
        final placement = DockPlacement.fromSerdeName(tag);
        if (placement == null) {
            throw new JsonError('unknown variant `$tag`, expected one of `center`, `left`, `bottom`, `right`');
        }
        final size = DockStateJson.pixels(DockStateJson.field(object, 'size'));
        final open = DockStateJson.bool(DockStateJson.field(object, 'open'));
        return new DockState(panel, placement, size, open);
    }

}

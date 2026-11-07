// Ported from gpui-kit 0.8.1: crates/base/src/dock/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Axis;
import gpui.Pixels;
import gpui.base.dock.JsonValue;

using gpui.base.dock.JsonValue.JsonValueTools;

/**
 * What a persisted node is: a split (`stack`), a tab group (`tabs`) or a
 * panel with its own payload (`panel`). Serialized externally tagged like
 * serde: `{"stack": {"sizes": [..], "axis": 0}}`, `{"tabs": {"active_index":
 * 0}}`, `{"panel": <value>}`.
 */
@:using(gpui.base.dock.PanelInfo.PanelInfoTools)
enum PanelInfo {
    /**
     * `axis`: 0 for horizontal, 1 for vertical.
     */
    Stack(sizes:Array<Pixels>, axis:Int);
    Tabs(activeIndex:Int);
    Panel(info:JsonValue);
}

class PanelInfoTools {

    public static function stack(sizes:Array<Pixels>, axis:Axis):PanelInfo {
        return PanelInfo.Stack(sizes, axis == Axis.Horizontal ? 0 : 1);
    }

    public static function tabs(activeIndex:Int):PanelInfo {
        return PanelInfo.Tabs(activeIndex);
    }

    public static function panel(info:JsonValue):PanelInfo {
        return PanelInfo.Panel(info);
    }

    public static function axis(self:PanelInfo):Null<Axis> {
        return switch self {
            case Stack(_, axis): axis == 0 ? Axis.Horizontal : Axis.Vertical;
            case _: null;
        }
    }

    public static function sizes(self:PanelInfo):Null<Array<Pixels>> {
        return switch self {
            case Stack(sizes, _): sizes;
            case _: null;
        }
    }

    public static function activeIndex(self:PanelInfo):Null<Int> {
        return switch self {
            case Tabs(activeIndex): activeIndex;
            case _: null;
        }
    }

    /**
     * Derived `PartialEq` (sizes compare as `f32`).
     */
    public static function equals(self:PanelInfo, other:PanelInfo):Bool {
        return switch [self, other] {
            case [Stack(sizesA, axisA), Stack(sizesB, axisB)]:
                if (axisA != axisB || sizesA.length != sizesB.length) return false;
                for (i in 0...sizesA.length) if ((sizesA[i] : Float) != (sizesB[i] : Float)) return false;
                true;
            case [Tabs(a), Tabs(b)]: a == b;
            case [Panel(a), Panel(b)]: a.equals(b);
            case _: false;
        }
    }

    public static function toJsonValue(self:PanelInfo):JsonValue {
        final object = new JsonObject();
        switch self {
            case Stack(sizes, axis):
                final inner = new JsonObject();
                inner.set('sizes', JArray([for (size in sizes) JFloat32(size)]));
                inner.set('axis', JInt(axis));
                object.set('stack', JObject(inner));
            case Tabs(activeIndex):
                final inner = new JsonObject();
                inner.set('active_index', JInt(activeIndex));
                object.set('tabs', JObject(inner));
            case Panel(info):
                object.set('panel', info);
        }
        return JObject(object);
    }

    public static function fromJsonValue(value:JsonValue):PanelInfo {
        switch value {
            case JObject(object) if (object.length() == 1):
                final key = object.keys[0];
                final inner = object.get(key);
                switch key {
                    case 'stack':
                        final fields = DockStateJson.struct(inner, 'struct variant PanelInfo::Stack');
                        final sizes = [for (size in DockStateJson.array(DockStateJson.field(fields, 'sizes'))) DockStateJson.pixels(size)];
                        return PanelInfo.Stack(sizes, DockStateJson.usize(DockStateJson.field(fields, 'axis')));
                    case 'tabs':
                        final fields = DockStateJson.struct(inner, 'struct variant PanelInfo::Tabs');
                        return PanelInfo.Tabs(DockStateJson.usize(DockStateJson.field(fields, 'active_index')));
                    case 'panel':
                        return PanelInfo.Panel(inner);
                    case _:
                        throw new JsonError('unknown variant `$key`, expected one of `stack`, `tabs`, `panel`');
                }
            case _:
                throw new JsonError('invalid type, expected enum PanelInfo');
        }
    }

    /**
     * Rust `{:?}`, for test messages.
     */
    public static function describe(self:PanelInfo):String {
        return switch self {
            case Stack(sizes, axis): 'Stack { sizes: [' + [for (size in sizes) JsonValueTools.formatF32(size)].join(', ') + '], axis: $axis }';
            case Tabs(activeIndex): 'Tabs { active_index: $activeIndex }';
            case Panel(info): 'Panel(' + info.stringify() + ')';
        }
    }

}

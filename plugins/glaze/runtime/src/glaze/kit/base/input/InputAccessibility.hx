// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (`InputAccessibility`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.kit.base.A11y.Role;

/**
 * Accessibility presentation for the editor's existing keyboard-focus boundary.
 *
 * Frames and their addon controls keep their own identities. This projection
 * does not create a focus handle or register another text Tab stop. The engine
 * supplies the live value and guards accessibility actions against its current
 * disabled, read-only and masked state.
 *
 * Glaze has no accessibility tree (see `glaze.Window`): the data is
 * kept so that facades can project it, the state does not export it.
 */
class InputAccessibility {

    final _role:Null<Role>;

    var _label:Null<String> = null;

    var _placeholder:Null<String> = null;

    var _accessibilityId:Null<String> = null;

    var _valueExposed:Bool = true;

    public function new(role:Null<Role>) {
        this._role = role;
    }

    public function withLabel(label:Null<String>):InputAccessibility {
        _label = label;
        return this;
    }

    public function withPlaceholder(placeholder:Null<String>):InputAccessibility {
        _placeholder = placeholder;
        return this;
    }

    public function withAccessibilityId(id:Null<String>):InputAccessibility {
        _accessibilityId = id;
        return this;
    }

    /** Suppress values for secret content even when the mask is revealed. */
    public function withValueExposed(exposed:Bool):InputAccessibility {
        _valueExposed = exposed;
        return this;
    }

    public inline function role():Null<Role> {
        return _role;
    }

    public inline function label():Null<String> {
        return _label;
    }

    public inline function placeholder():Null<String> {
        return _placeholder;
    }

    public inline function accessibilityId():Null<String> {
        return _accessibilityId;
    }

    public inline function valueExposed():Bool {
        return _valueExposed;
    }

}

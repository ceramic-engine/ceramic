// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.Point;

/**
 * A selection endpoint anchored to a participant's content coordinates.
 * Immutable: `withContentKey` returns a new value.
 */
class TextSelectionEndpoint {

    final _entityId:Null<Int>;

    final _point:Point;

    final _contentKey:Null<TextSelectionContentKey>;

    /** Creates an endpoint at a participant-relative content point. */
    @:allow(gpui.base, tests)
    function new(entityId:Null<Int>, point:Point, ?contentKey:Null<TextSelectionContentKey>) {
        _entityId = entityId;
        _point = point;
        _contentKey = contentKey;
    }

    /** Sets participant-defined endpoint metadata. */
    @:allow(gpui.base, tests)
    function withContentKey(contentKey:TextSelectionContentKey):TextSelectionEndpoint {
        return new TextSelectionEndpoint(_entityId, _point, contentKey);
    }

    /** Returns the participant which owns this endpoint, when it hit one. */
    public inline function entityId():Null<Int> {
        return _entityId;
    }

    /** Returns the participant-relative content point. */
    public inline function contentPoint():Point {
        return _point;
    }

    /** Returns participant-defined endpoint metadata captured when it hit a participant. */
    public inline function contentKey():Null<TextSelectionContentKey> {
        return _contentKey;
    }

    public function equals(other:Null<TextSelectionEndpoint>):Bool {
        return other != null
            && _entityId == other._entityId
            && _point.equals(other._point)
            && _contentKey == other._contentKey;
    }

    /** `Option<TextSelectionEndpoint>` equality. */
    public static function eq(a:Null<TextSelectionEndpoint>, b:Null<TextSelectionEndpoint>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    public function toString():String {
        return 'TextSelectionEndpoint { entity_id: $_entityId, point: $_point, content_key: $_contentKey }';
    }

}

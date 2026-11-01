// Ported from gpui-kit 0.8.1: crates/component/src/diff/decoration.rs (`DiffGutterMarker`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.ElementId;

/**
 * An interactive marker in the lane between the line numbers and the code,
 * such as a comment or diagnostic indicator that opens a details panel.
 *
 * The application renders it with `Diff.renderGutterMarker`, usually as a
 * small button, and owns the panel and its focus.
 */
class DiffGutterMarker {

    final _id:ElementId;

    final _position:DiffLinePosition;

    var _label:String = '';

    /** Places a marker beside a source line. */
    public function new(id:ElementId, position:DiffLinePosition) {
        _id = id;
        _position = position;
    }

    /** Sets the accessible label that the rendered marker should announce. */
    public function withLabel(label:String):DiffGutterMarker {
        final marker = new DiffGutterMarker(_id, _position);
        marker._label = label;
        return marker;
    }

    public function id():ElementId {
        return _id;
    }

    public function position():DiffLinePosition {
        return _position;
    }

    public function label():String {
        return _label;
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/mod.rs (`Editor`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Component;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Window;

/**
 * An unstyled source-code editor: renders its state (Rust `Entity<EditorState>`).
 */
class Editor extends Component {

    final state:Entity<EditorState>;

    public function new(state:Entity<EditorState>) {
        super();
        this.state = state;
    }

    public function render(_:Window, _:App):IntoElement {
        return state;
    }

}

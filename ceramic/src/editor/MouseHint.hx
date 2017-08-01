package editor;

import ceramic.Visual;
import ceramic.Text;
import ceramic.Color;

import ceramic.Shortcuts.*;

class MouseHint extends Visual {

    public var text:Text;

/// Lifecycle

    public function new() {

        super();

        depth = 999999;
        childrenDepthRange = 0.5;

        text = new Text();
        text.content = 'resize';
        text.color = Color.RED;
        text.pointSize = 13;
        text.pos(0, 0);
        add(text);

    } //new

} //MouseHint

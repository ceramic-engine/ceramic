package elements;

import ceramic.Component;
import ceramic.Entity;
import ceramic.Text;

class ItalicText extends Entity implements Component {

    public var entity:Text;

    public var skewX(default,set):Float = 10;
    function set_skewX(skewX:Float):Float {
        if (this.skewX == skewX) return skewX;
        if (entity != null) applyItalicTransform();
        return skewX;
    }

/// Lifecycle

    function bindAsComponent():Void {

        entity.onGlyphQuadsChange(this, applyItalicTransform);

    }

/// Internal

    function applyItalicTransform() {

        if (entity.glyphQuads == null) return;

        for (i in 0...entity.glyphQuads.length) {
            var glyph = entity.glyphQuads[i];
            glyph.skewX = skewX;
        }

    }

}

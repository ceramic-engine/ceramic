package elements;

import ceramic.AlphaColor;
import ceramic.Color;
import ceramic.Mesh;

using ceramic.Extensions;

class BiBorderedTriangle extends Mesh {

/// Overrides

    override function set_width(width:Float):Float {
        super.set_width(width);
        contentDirty = true;
        return width;

    }

    override function set_height(height:Float):Float {
        super.set_height(height);
        contentDirty = true;
        return height;

    }

/// Properties

    public var innerColor(default,set):Color = Color.WHITE;
    inline function set_innerColor(innerColor:Color):Color {
        if (this.innerColor != innerColor) {
            for (i in 0...3) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(innerColor, existing.alpha));
            }
        }
        return innerColor;
    }

    public var innerAlpha(default,set):Float = 1;
    inline function set_innerAlpha(innerAlpha:Float):Float {
        if (this.innerAlpha != innerAlpha) {
            var alphaInt = Math.round(innerAlpha * 255);
            for (i in 0...3) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(existing.rgb,alphaInt));
            }
        }
        return innerAlpha;
    }

    public var borderSize(default,set):Float = 1;
    inline function set_borderSize(borderSize:Float):Float {
        if (this.borderSize != borderSize) {
            this.borderSize = borderSize;
            contentDirty = true;
        }
        return borderSize;
    }

    public var borderColor(default,set):Color = Color.BLACK;
    inline function set_borderColor(borderColor:Color):Color {
        if (this.borderColor != borderColor) {
            this.borderColor = borderColor;
            for (i in 3...15) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(borderColor, existing.alpha));
            }
        }
        return borderColor;
    }

    public var borderAlpha(default,set):Float = 1.0;
    inline function set_borderAlpha(borderAlpha:Float):Float {
        if (this.borderAlpha != borderAlpha) {
            this.borderAlpha = borderAlpha;
            var alphaInt = Math.round(borderAlpha * 255);
            for (i in 3...15) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(existing.rgb, alphaInt));
            }
        }
        return borderAlpha;
    }

/// Lifecycle

    public function new() {

        super();

        vertices = [
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0
        ];
        indices = [
            0, 1, 2,
            0, 3, 4,
            0, 4, 1,
            1, 4, 2,
            4, 5, 2
        ];

        colorMapping = INDICES;
        colors = [];
        for (i in 0...15)
            colors.push(new AlphaColor(Color.WHITE));

        innerColor = Color.WHITE;
        borderColor = Color.GRAY;

    }

    override function computeContent() {

        super.computeContent();

        updateVertices();

    }

    inline function updateVertices() {

        // Triangle
        //
        vertices.unsafeSet(0, 0.0);
        vertices.unsafeSet(1, height);

        vertices.unsafeSet(2, width * 0.5);
        vertices.unsafeSet(3, 0.0);

        vertices.unsafeSet(4, width);
        vertices.unsafeSet(5, height);

        // Border
        //
        vertices.unsafeSet(6, -borderSize);
        vertices.unsafeSet(7, height);

        vertices.unsafeSet(8, width * 0.5);
        vertices.unsafeSet(9, -borderSize);

        vertices.unsafeSet(10, width + borderSize);
        vertices.unsafeSet(11, height);

    }

}

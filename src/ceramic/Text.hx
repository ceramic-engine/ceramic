package ceramic;

import ceramic.BitmapFont;

using unifill.Unifill;

enum TextAlign {
    LEFT;
    RIGHT;
    CENTER;
}

class Text extends Visual {

    public var color:Color = Color.WHITE;

    public var content(default,set):String = '';
    function set_content(content:String):String {
        if (this.content == content) return content;
        contentDirty = true;
        this.content = content;
        return content;
    }

    public var pointSize(default,set):Float = 20;
    function set_pointSize(pointSize:Float):Float {
        if (this.pointSize == pointSize) return pointSize;
        contentDirty = true;
        this.pointSize = pointSize;
        return pointSize;
    }

    public var lineHeight(default,set):Float = 1.0;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        contentDirty = true;
        this.lineHeight = lineHeight;
        return lineHeight;
    }

    public var letterSpacing(default,set):Float = 0.0;
    function set_letterSpacing(letterSpacing:Float):Float {
        if (this.letterSpacing == letterSpacing) return letterSpacing;
        contentDirty = true;
        this.letterSpacing = letterSpacing;
        return letterSpacing;
    }

    public var font(default,set):BitmapFont;
    function set_font(font:BitmapFont):BitmapFont {
        if (this.font == font) return font;
        contentDirty = true;
        this.font = font;
        return font;
    }

    public var align(default,set):TextAlign = LEFT;
    function set_align(align:TextAlign):TextAlign {
        if (this.align == align) return align;
        contentDirty = true;
        this.align = align;
        return align;
    }

/// Overrides

    override function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;

        // Ensure text glyphs have the requested depth
        for (quad in glyphQuads) {
            quad.depth = depth;
        }

        return super.set_depth(depth);
    }

    override function get_width():Float {
        if (contentDirty) computeContent();
        return super.get_width();
    }
    override function set_width(width:Float):Float {
        // Only adjust scaleX to match requested width
        if (this.width == width) return width;
        scaleX = width / realWidth;
        matrixDirty = true;
        return width;
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }
    override function set_height(height:Float):Float {
        // Only adjust scaleY to match requested height
        if (this.height == height) return height;
        scaleX = height / realHeight;
        matrixDirty = true;
        return height;
    }

/// Lifecycle

    override public function new() {

        super();

    } //new

    function destroy() {

        glyphQuads = null;

    } //destroy

/// Display

    var glyphQuads:Array<Quad> = [];

    override function computeContent() {

        if (font == null) {
            realWidth = 0;
            realHeight = 0;
            contentDirty = false;
            return;
        }

        var x = 0.0;
        var y = 0.0;
        var len = content.uLength();
        var sizeFactor = pointSize / font.pointSize;
        var char = null;
        var code = -1;
        var prevChar = null;
        var prevCode = -1;
        var i = 0;
        var glyph:BitmapFontCharacter = null;
        var lineWidths:Array<Float> = [];
        var lineQuads:Array<Array<Quad>> = [[]];
        var usedQuads = 0;
        
        while (i < len) {

            prevChar = char;
            prevCode = code;
            char = content.uCharAt(i);
            code = char.uCharCodeAt(0);

            if (char == "\n") {
                prevChar = null;
                prevCode = 0;
                i++;
                y += pointSize * lineHeight;
                lineWidths.push(x + (glyph != null ? (glyph.width - glyph.xAdvance) * sizeFactor - letterSpacing : 0));
                lineQuads.push([]);
                x = 0;
                continue;
            }

            glyph = font.chars.get(code);

            if (prevChar != null) {
                x += font.kerning(prevCode, code) * sizeFactor;
            }

            // Reuse or create quad
            var quad:Quad = usedQuads < glyphQuads.length ? glyphQuads[usedQuads] : null;
            if (quad == null) {
                quad = new Quad();
                glyphQuads.push(quad);
                add(quad);
            }
            usedQuads++;

            quad.texture = font.pages.get(glyph.page);
            quad.color = color;
            quad.depth = depth;
            quad.frame(
                glyph.x / quad.texture.density,
                glyph.y / quad.texture.density,
                glyph.width / quad.texture.density,
                glyph.height / quad.texture.density
            );
            quad.anchor(0, 0);
            quad.pos(x + glyph.xOffset * sizeFactor, y + glyph.yOffset * sizeFactor);
            quad.size(glyph.width * sizeFactor, glyph.height * sizeFactor);

            x += glyph.xAdvance * sizeFactor + letterSpacing;
            lineQuads[lineQuads.length-1].push(quad);

            i++;

        }

        if (x > 0) {
            lineWidths.push(x + (glyph != null ? (glyph.width - glyph.xAdvance) * sizeFactor - letterSpacing : 0));
        }

        // Remove unused quads
        while (usedQuads < glyphQuads.length) {
            usedQuads++;
            var quad = glyphQuads.pop();
            quad.destroy();
        }

        // Compute width/height from content
        var maxLineWidth = 0.0;
        for (lineWidth in lineWidths) {
            maxLineWidth = Math.max(lineWidth, maxLineWidth);
        }
        realWidth = maxLineWidth;
        realHeight = lineWidths.length * pointSize * lineHeight;

        // Align quads as requested
        switch (align) {
            case CENTER:
                for (i in 0...lineWidths.length) {
                    var diffX = (maxLineWidth - lineWidths[i]) * 0.5;
                    for (quad in lineQuads[i]) {
                        quad.x += diffX;
                    }
                }
            case RIGHT:
                for (i in 0...lineWidths.length) {
                    var diffX = maxLineWidth - lineWidths[i];
                    for (quad in lineQuads[i]) {
                        quad.x += diffX;
                    }
                }
            default:
        }
        
        contentDirty = false;

    } //computeContent

} //Text

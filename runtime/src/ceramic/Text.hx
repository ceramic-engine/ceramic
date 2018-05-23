package ceramic;

import ceramic.BitmapFont;
import ceramic.Assets;
import ceramic.Shortcuts.*;

using unifill.Unifill;

@editable({ implicitSize: true })
class Text extends Visual {

    @editable
    public var color(default,set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color == color) return color;
        this.color = color;

        // Ensure text glyphs have the requested color
        for (quad in glyphQuads) {
            quad.color = color;
        }

        return color;
    }

    @editable({ multiline: true })
    public var content(default,set):String = '';
    function set_content(content:String):String {
        if (this.content == content) return content;
        contentDirty = true;
        this.content = content;
        return content;
    }

    @editable
    public var pointSize(default,set):Float = 20;
    function set_pointSize(pointSize:Float):Float {
        if (this.pointSize == pointSize) return pointSize;
        contentDirty = true;
        this.pointSize = pointSize;
        return pointSize;
    }

    @editable
    public var lineHeight(default,set):Float = 1.0;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        contentDirty = true;
        this.lineHeight = lineHeight;
        return lineHeight;
    }

    @editable
    public var letterSpacing(default,set):Float = 0.0;
    function set_letterSpacing(letterSpacing:Float):Float {
        if (this.letterSpacing == letterSpacing) return letterSpacing;
        contentDirty = true;
        this.letterSpacing = letterSpacing;
        return letterSpacing;
    }

    @editable
    public var font(default,set):BitmapFont;
    function set_font(font:BitmapFont):BitmapFont {
        
        if (font == null) {
            font = app.defaultFont;
        }

        if (this.font == font) return font;

        // Unbind previous font destroy event
        if (this.font != null) {
            this.font.offDestroy(fontDestroyed);
            if (this.font.asset != null) this.font.asset.release();
        }

        contentDirty = true;
        this.font = font;

        if (this.font != null) {
            // Ensure we remove the font if it gets destroyed
            this.font.onDestroy(this, fontDestroyed);
            if (this.font.asset != null) this.font.asset.retain();
        }

        return font;
    }

    @editable
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

    function scaleWidth(targetWidth:Float):Void {
        // Only adjust scaleX to match requested width
        if (_height == targetWidth) return;
        scaleX = targetWidth / _width;
        matrixDirty = true;
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }

    function scaleHeight(targetHeight:Float):Void {
        // Only adjust scaleY to match requested height
        if (_height == targetHeight) return;
        scaleY = targetHeight / _height;
        matrixDirty = true;
    }

    override function set_blending(blending:Blending):Blending {
        if (this.blending == blending) return blending;
        this.blending = blending;
        if (glyphQuads != null) {
            for (quad in glyphQuads) {
                quad.blending = blending;
            }
        }
        return blending;
    }

/// Lifecycle

    override public function new() {

        super();

        // Default font
        font = app.defaultFont;

    } //new

    function destroy() {

        glyphQuads = null;

    } //destroy

/// Display

    var glyphQuads:Array<Quad> = [];

    override function computeContent() {

        if (font == null) {
            width = 0;
            height = 0;
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
                y += lineHeight * font.lineHeight * sizeFactor;
                lineWidths.push(x + (glyph != null ? (glyph.xOffset + glyph.width - glyph.xAdvance) * sizeFactor - letterSpacing : 0));
                lineQuads.push([]);
                x = 0;
                continue;
            }

            glyph = font.chars.get(code);
            if (glyph == null) {
                i++;
                continue;
            }

            if (prevChar != null) {
                x += font.kerning(prevCode, code) * sizeFactor;
            }

            // Reuse or create quad
            var quad:Quad = usedQuads < glyphQuads.length ? glyphQuads[usedQuads] : null;
            if (quad == null) {
                quad = new Quad();
                quad.inheritAlpha = true;
                glyphQuads.push(quad);
                add(quad);
            }
            usedQuads++;

            quad.texture = font.pages.get(glyph.page);
            quad.color = color;
            quad.depth = depth;
            quad.blending = blending;
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
            lineWidths.push(x);
        }

        // Remove unused quads
        while (usedQuads < glyphQuads.length) {
            var quad = glyphQuads.pop();
            quad.destroy();
        }

        // Compute width/height from content
        var maxLineWidth = 0.0;
        for (lineWidth in lineWidths) {
            maxLineWidth = Math.max(lineWidth, maxLineWidth);
        }
        this.width = maxLineWidth;
        this.height = (lineWidths.length - 1) * lineHeight * font.lineHeight * sizeFactor + font.lineHeight * sizeFactor;

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
        matrixDirty = true;

    } //computeContent

/// Font destroyed

    function fontDestroyed() {

        // Remove font (and set default one) because it has been destroyed
        this.font = app.defaultFont;

    } //fontDestroyed

/// Print

    function toString():String {

        if (id != null) {
            return 'Text($id $content)';
        } else {
            return 'Text($content)';
        }

    } //toString

} //Text

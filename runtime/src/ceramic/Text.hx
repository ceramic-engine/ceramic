package ceramic;

import ceramic.BitmapFont;
import ceramic.Assets;
import ceramic.Shortcuts.*;

using unifill.Unifill;
using ceramic.Extensions;

@editable({ implicitSize: true })
class Text extends Visual {
    
    @event function glyphQuadsChange();

    public var glyphQuads(default,null):Array<GlyphQuad> = [];

    public var numLines(get,null):Int = 1;
    function get_numLines():Int {
        if (contentDirty) computeContent();
        return this.numLines;
    }

    @editable
    public var color(default,set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color == color) return color;
        this.color = color;

        // Ensure text glyphs have the requested color
        if (glyphQuads != null) {
            for (i in 0...glyphQuads.length) {
                var quad = glyphQuads.unsafeGet(i);
                quad.color = color;
            }
        }

        return color;
    }

    @editable({ multiline: true })
    public var content(default,set):String = '';
    function set_content(content:String):String {
        Assert.assert(content != null, 'Text.content should not be null');
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

    /** If set to `true`, text will be displayed with line breaks
        as needed so that it fits in the requested width. */
    @editable
    public var fitWidth(default,set):Float = -1;
    function set_fitWidth(fitWidth:Float):Float {
        if (this.fitWidth == fitWidth) return fitWidth;
        this.fitWidth = fitWidth;
        contentDirty = true;
        return fitWidth;
    }

    @editable
    public var maxLineDiff(default,set):Float = -1;
    function set_maxLineDiff(maxLineDiff:Float):Float {
        if (this.maxLineDiff == maxLineDiff) return maxLineDiff;
        this.maxLineDiff = maxLineDiff;
        if (fitWidth != -1) contentDirty = true;
        return maxLineDiff;
    }

/// Overrides

    override function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;

        // Ensure text glyphs have the requested depth
        if (glyphQuads != null) {
            for (i in 0...glyphQuads.length) {
                var quad = glyphQuads.unsafeGet(i);
                quad.depth = depth;
            }
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
            for (i in 0...glyphQuads.length) {
                var quad = glyphQuads.unsafeGet(i);
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

    override function destroy() {

        if (glyphQuads != null) {
            for (i in 0...glyphQuads.length) {
                glyphQuads[i].destroy();
            }
            glyphQuads = null;
        }

    } //destroy

/// Display

    override function computeContent() {

        if (font == null) {
            width = 0;
            height = 0;
            contentDirty = false;
            return;
        }

        numLines = computeGlyphQuads(fitWidth, maxLineDiff);

        contentDirty = false;
        matrixDirty = true;
        
        emitGlyphQuadsChange();

    } //computeContent

    function computeGlyphQuads(fitWidth:Float, maxLineDiff:Float, fixedNumLines:Int = -1) {

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
        var isLineBreak = false;
        var isWhiteSpace = false;
        var justDidBreakToFit = false;
        var hasSpaceInLine = false;
        var wasWhiteSpace = false;
        var numCharsBeforeLine = 0;
        
        while (i < len) {

            prevChar = char;
            prevCode = code;
            
            char = content.uCharAt(i);
            code = char.uCharCodeAt(0);

            isLineBreak = (char == "\n");
            isWhiteSpace = (char == ' ');

            if (!hasSpaceInLine && isWhiteSpace) hasSpaceInLine = true;

            if (isLineBreak || isWhiteSpace || i == len - 1) {
                if (!justDidBreakToFit && fitWidth >= 0 && x >= fitWidth && hasSpaceInLine) {
                    justDidBreakToFit = true;
                    // Rewind last word because it doesn't fit
                    while (i > 0) {
                        i--;
                        char = content.uCharAt(i);
                        code = char.uCharCodeAt(0);
                        if (i > 0) {
                            prevChar = content.uCharAt(i - 1);
                            prevCode = prevChar.uCharCodeAt(0);
                            glyph = font.chars.get(prevCode);
                        } else {
                            prevChar = null;
                            prevCode = -1;
                            glyph = null;
                        }
                        if (prevChar != null) {
                            x -= font.kerning(prevCode, code) * sizeFactor;
                        }
                        if (glyph != null) {
                            x -= glyph.xAdvance * sizeFactor + letterSpacing;
                            usedQuads--;
                            lineQuads[lineQuads.length-1].pop();
                        }
                        if (char == ' ') {
                            char = "\n";
                            code = char.uCharCodeAt(0);
                            isLineBreak = true;
                            isWhiteSpace = false;
                            break;
                        }
                    }
                }
                else {
                    justDidBreakToFit = false;
                }
            }

            if (isLineBreak) {
                hasSpaceInLine = false;
                prevChar = null;
                prevCode = -1;
                i++;
                numCharsBeforeLine = i;
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
            var quad:GlyphQuad = usedQuads < glyphQuads.length ? glyphQuads[usedQuads] : null;
            if (quad == null) {
                quad = new GlyphQuad();
                quad.inheritAlpha = true;
                glyphQuads.push(quad);
                add(quad);
            }
            usedQuads++;

            quad.char = char;
            quad.code = code;
            quad.index = i;
            quad.posInLine = i - numCharsBeforeLine;
            quad.line = lineQuads.length - 1;
            quad.texture = font.pages.get(glyph.page);
            quad.color = color;
            quad.depth = depth;
            quad.blending = blending;
            quad.glyphX = x;
            quad.glyphY = y;
            quad.glyphAdvance = glyph.xAdvance * sizeFactor + letterSpacing;
            quad.glyph = glyph;
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
        for (i in 0...lineWidths.length) {
            var lineWidth = lineWidths.unsafeGet(i);
            maxLineWidth = Math.max(lineWidth, maxLineWidth);
        }
        this.width = maxLineWidth;
        this.height = (lineWidths.length - 1) * lineHeight * font.lineHeight * sizeFactor + font.lineHeight * sizeFactor;

        // Align quads as requested
        switch (align) {
            case CENTER:
                for (i in 0...lineWidths.length) {
                    var diffX = (maxLineWidth - lineWidths.unsafeGet(i)) * 0.5;
                    var quads = lineQuads.unsafeGet(i);
                    for (j in 0...quads.length) {
                        var quad = quads.unsafeGet(j);
                        quad.x += diffX;
                    }
                }
            case RIGHT:
                for (i in 0...lineWidths.length) {
                    var diffX = maxLineWidth - lineWidths.unsafeGet(i);
                    var quads = lineQuads.unsafeGet(i);
                    for (j in 0...quads.length) {
                        var quad = quads.unsafeGet(j);
                        quad.x += diffX;
                    }
                }
            default:
        }

        if ((fixedNumLines == -1 || fixedNumLines == lineWidths.length) && fitWidth > 0 && maxLineDiff != -1 && fitWidth > pointSize) {
            // Check if lines have similar sizes
            var lineDiff = 0.0;
            var maxLineDiffValue = this.fitWidth * maxLineDiff;
            for (i in 0...lineWidths.length) {
                for (j in 0...lineWidths.length) {
                    var newDiff = lineWidths[i] - lineWidths[j];
                    if (newDiff < 0) newDiff = -newDiff;
                    if (newDiff > lineDiff) lineDiff = newDiff;
                    if (lineDiff > maxLineDiffValue) {
                        break;
                    }
                }
            }

            if (lineDiff > maxLineDiffValue) {
                var numLines = computeGlyphQuads(fitWidth - pointSize, maxLineDiff, lineWidths.length);
                if (numLines > lineWidths.length) {
                    // Restore previous state
                    computeGlyphQuads(fitWidth, -1, lineWidths.length);
                }
            }
        }

        return lineWidths.length;

    } //computeGlyphQuads

/// Font destroyed

    function fontDestroyed() {

        // Remove font (and set default one) because it has been destroyed
        this.font = app.defaultFont;

    } //fontDestroyed

/// Print

    override function toString():String {

        if (id != null) {
            return 'Text($id $content)';
        } else {
            return 'Text($content)';
        }

    } //toString

} //Text

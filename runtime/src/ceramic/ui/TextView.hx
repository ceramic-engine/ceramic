package ceramic.ui;

using StringTools;

class TextView extends View {

    public var text(default,null):Text;

    public var verticalAlign(default,set):LayoutAlign = TOP;
    function set_verticalAlign(verticalAlign:LayoutAlign):LayoutAlign {
        if (this.verticalAlign == verticalAlign) return verticalAlign;
        this.verticalAlign = verticalAlign;
        layoutDirty = true;
        return verticalAlign;
    }

    public var font(get,set):BitmapFont;
    inline function get_font():BitmapFont return text.font;
    function set_font(font:BitmapFont):BitmapFont {
        if (this.font == font) return font;
        text.font = font;
        layoutDirty = true;
        return font;
    }

    public var textColor(get,set):Color;
    inline function get_textColor():Color return text.color;
    function set_textColor(textColor:Color):Color {
        if (this.textColor == textColor) return textColor;
        text.color = textColor;
        return textColor;
    }

    public var content(get,set):String;
    inline function get_content():String return text.content;
    function set_content(content:String):String {
        if (this.content == content) return content;
        text.content = content;
        layoutDirty = true;
        return content;
    }

    public var pointSize(get,set):Float;
    inline function get_pointSize():Float return text.pointSize;
    function set_pointSize(pointSize:Float):Float {
        if (this.pointSize == pointSize) return pointSize;
        text.pointSize = pointSize;
        layoutDirty = true;
        return pointSize;
    }

    public var lineHeight(get,set):Float;
    inline function get_lineHeight():Float return text.lineHeight;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        text.lineHeight = lineHeight;
        layoutDirty = true;
        return lineHeight;
    }

    public var letterSpacing(get,set):Float;
    inline function get_letterSpacing():Float return text.letterSpacing;
    function set_letterSpacing(letterSpacing:Float):Float {
        if (this.letterSpacing == letterSpacing) return letterSpacing;
        text.letterSpacing = letterSpacing;
        layoutDirty = true;
        return letterSpacing;
    }

    public var align(get,set):TextAlign;
    inline function get_align():TextAlign return text.align;
    function set_align(align:TextAlign):TextAlign {
        if (this.align == align) return align;
        text.align = align;
        layoutDirty = true;
        return align;
    }

    public function new() {

        super();

        text = new Text();
        add(text);

        transparent = true;

    } //new

    override function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool) {
        
        super.computeSize(parentWidth, parentHeight, layoutMask, persist);

        var shouldComputeWidth = false;
        var shouldComputeHeight = false;

        if (ViewSize.isAuto(viewWidth)) {
            shouldComputeWidth = true;
        }

        if (ViewSize.isAuto(viewHeight)) {
            shouldComputeHeight = true;
        }

        // Compute size from text
        if (shouldComputeHeight || shouldComputeWidth) {
            if (computedWidth > 0) {
                if (!shouldComputeWidth) {
                    text.fitWidth = computedWidth - paddingLeft - paddingRight;
                } else {
                    text.fitWidth = computedWidth;
                }
                text.maxLineDiff = 0.5;
            } else {
                text.fitWidth = -1;
            }

            var textWidth = text.width;
            var textHeight = text.height;
            if (shouldComputeHeight) {
                computedHeight = textHeight;
            }
            if (shouldComputeWidth) {
                computedWidth = textWidth;
            }
        }

        // Force fixed width if not flexible
        if (!layoutMask.canIncreaseWidth()) {
            if (computedWidth > parentWidth) {
                computedWidth = parentWidth;
            }
        }
        if (!layoutMask.canDecreaseWidth()) {
            if (computedWidth < parentWidth) {
                computedWidth = parentWidth;
            }
        }

        // Force fixed height if not flexible
        if (!layoutMask.canIncreaseHeight()) {
            if (computedHeight > parentHeight) {
                computedHeight = parentHeight;
            }
        }
        if (!layoutMask.canDecreaseHeight()) {
            if (computedHeight < parentHeight) {
                computedHeight = parentHeight;
            }
        }

        // Add padding
        if (shouldComputeWidth) {
            computedWidth += paddingLeft + paddingRight;
        }
        if (shouldComputeHeight) {
            computedHeight += paddingTop + paddingBottom;
        }

        // Round
        computedWidth = Math.round(computedWidth);
        computedHeight = Math.round(computedHeight);

    } //computeSize

    override function layout() {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, width);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, height);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, width);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, height);
        
        switch [verticalAlign, text.align] {
            case [TOP, LEFT]:
                text.anchor(0, 0);
                text.pos(
                    paddingLeft,
                    paddingTop
                );
            case [TOP, RIGHT]:
                text.anchor(1, 0);
                text.pos(
                    width - paddingRight,
                    paddingTop
                );
            case [TOP, CENTER]:
                text.anchor(0.5, 0);
                text.pos(
                    width * 0.5 + paddingLeft - paddingRight,
                    paddingTop
                );
            case [CENTER | LEFT | RIGHT, LEFT]:
                text.anchor(0, 0.5);
                text.pos(
                    paddingLeft,
                    height * 0.5 + paddingTop - paddingBottom
                );
            case [CENTER | LEFT | RIGHT, RIGHT]:
                text.anchor(1, 0.5);
                text.pos(
                    width - paddingRight,
                    height * 0.5 + paddingTop - paddingBottom
                );
            case [CENTER | LEFT | RIGHT, CENTER]:
                text.anchor(0.5, 0.5);
                text.pos(
                    width * 0.5 + paddingLeft - paddingRight,
                    height * 0.5 + paddingTop - paddingBottom
                );
            case [BOTTOM, LEFT]:
                text.anchor(0, 1);
                text.pos(
                    paddingLeft,
                    height - paddingBottom
                );
            case [BOTTOM, RIGHT]:
                text.anchor(1, 1);
                text.pos(
                    width - paddingRight,
                    height - paddingBottom
                );
            case [BOTTOM, CENTER]:
                text.anchor(0.5, 1);
                text.pos(
                    width * 0.5 + paddingLeft - paddingRight,
                    height - paddingBottom
                );
        }

    } //layout

} //View

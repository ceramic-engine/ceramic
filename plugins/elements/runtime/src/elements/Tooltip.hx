package elements;

import ceramic.Component;
import ceramic.Point;
import ceramic.Quad;
import ceramic.Shortcuts.*;
import ceramic.Text;
import ceramic.Triangle;
import ceramic.Visual;
import elements.Context.context;
import tracker.Observable;

class Tooltip extends Visual implements Component implements Observable {

    static var _point:Point = new Point(0, 0);

    @observe public var content:String;

    var entity:Visual;

    var text:Text;

    var bubble:Quad;

    var bubbleTriangle:Triangle;

    public static function tooltip(visual:Visual, content:String) {

        if (content == null) {
            visual.removeComponent('tooltip');
        }
        else {
            var tooltipComponent:Tooltip = cast visual.component('tooltip');
            if (tooltipComponent == null) {
                tooltipComponent = new Tooltip(content);
                visual.component('tooltip', tooltipComponent);
            }
            else {
                tooltipComponent.content = content;
            }
        }

    }

    public function new(content:String) {

        super();

        this.content = content;
        depth = 21;
        context.view.add(this);

        anchor(0, 0.5);

        bubble = new Quad();
        bubble.depth = 1;
        add(bubble);

        bubbleTriangle = new Triangle();
        bubbleTriangle.depth = 1;
        add(bubbleTriangle);

        text = new Text();
        text.fitWidth = 100;
        text.depth = 2;
        text.preRenderedSize = 20;
        text.pointSize = 11;
        text.align = CENTER;
        add(text);

        autorun(updateTextContent);
        autorun(updateStyle);

    }

    function bindAsComponent() {

        active = false;

        entity.onPointerOver(this, _ -> {
            if (screen.isPointerDown)
                return;

            active = true;

            var gap = 24;

            entity.visualToScreen(entity.width * 0.5, entity.height * 0.5, _point);
            if (parent != null)
                parent.screenToVisual(_point.x, _point.y, _point);
            pos(_point.x, gap + _point.y);
        });

        entity.onPointerOut(this, _ -> {
            active = false;
        });

    }

    function updateTextContent() {

        text.content = this.content;

        var pad = 6;
        var triangleSize = 5;
        var offsetX = -(text.width + pad * 2) * 0.5;

        text.pos(offsetX + pad, triangleSize + pad);

        size(text.width + pad * 2, text.height + pad * 2);

        bubble.size(width, height);
        bubble.pos(offsetX, triangleSize);

        bubbleTriangle.anchor(0.5, 1);
        bubbleTriangle.size(8, triangleSize);
        bubbleTriangle.pos(0, triangleSize);

    }

    function updateStyle() {

        var theme = context.theme;

        text.color = theme.lightTextColor;
        text.font = theme.mediumFont;

        bubble.color = theme.overlayBackgroundColor;
        bubble.alpha = theme.overlayBackgroundAlpha;

        bubbleTriangle.color = bubble.color;
        bubbleTriangle.alpha = bubble.alpha;

    }

}
package elements;

import ceramic.TextView;
import elements.Context.context;
import tracker.Observable;

class LabelView extends TextView implements Observable {

    @observe public var disabled:Bool = false;

    public function new() {

        super();

        viewSize(fill(), auto());
        align = LEFT;
        verticalAlign = CENTER;
        pointSize = 12;
        preRenderedSize = 20;

        autorun(updateStyle);

    }

    function updateStyle() {

        var theme = context.theme;

        if (disabled) {
            textColor = theme.darkTextColor;
        }
        else {
            textColor = theme.lightTextColor;
        }

        font = theme.mediumFont;

    }

}

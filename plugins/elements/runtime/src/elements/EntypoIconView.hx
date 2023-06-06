package elements;

import ceramic.TextView;
import elements.Context.context;
import tracker.Observable;

class EntypoIconView extends TextView implements Observable {

    @observe public var icon:Entypo = NOTE_BEAMED;

    public function new() {

        super();

        anchor(0.5, 0.5);
        align = CENTER;
        verticalAlign = CENTER;
        pointSize = 16;
        context.assets.ensureFont('font:entypo', null, null, function(fontAsset) {
            font = fontAsset.font;
            preRenderedSize = 20;
            autorun(updateContent);
        });

    }

    function updateContent() {

        this.content = String.fromCharCode(icon);

    }

}
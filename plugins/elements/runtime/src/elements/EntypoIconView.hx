package elements;

import ceramic.TextView;
import elements.Context.context;
import tracker.Observable;

/**
 * A view component for displaying Entypo font icons.
 * 
 * EntypoIconView is a specialized TextView that renders icons from the Entypo icon font.
 * It provides a simple way to display any of the 411 premium pictograms available in the
 * Entypo font collection.
 * 
 * The view automatically loads the Entypo font, centers the icon both horizontally and
 * vertically, and updates its content when the icon property changes.
 * 
 * Example usage:
 * ```haxe
 * var iconView = new EntypoIconView();
 * iconView.icon = Entypo.HEART;
 * iconView.color = Color.RED;
 * iconView.pointSize = 24;
 * ```
 * 
 * @see Entypo for available icon constants
 */
class EntypoIconView extends TextView implements Observable {

    /**
     * The Entypo icon to display.
     * 
     * Changing this property will automatically update the displayed icon.
     * The icon is rendered as a Unicode character from the Entypo font.
     * 
     * @default NOTE_BEAMED
     */
    @observe public var icon:Entypo = NOTE_BEAMED;

    /**
     * Creates a new EntypoIconView instance.
     * 
     * The constructor initializes the view with default settings:
     * - Centers the icon both horizontally and vertically
     * - Sets the default point size to 16
     * - Loads the Entypo font asynchronously
     * - Sets up automatic content updates when the icon property changes
     */
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

    /**
     * Updates the displayed content based on the current icon value.
     * 
     * This method is automatically called whenever the icon property changes,
     * converting the icon's numeric code point to the corresponding Unicode character.
     */
    function updateContent() {

        this.content = String.fromCharCode(icon);

    }

}
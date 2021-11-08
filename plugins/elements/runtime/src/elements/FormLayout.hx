package elements;

import ceramic.ColumnLayout;
import elements.Context.context;
import elements.TabFocus;

class FormLayout extends ColumnLayout {

    @component public var tabFocus:TabFocus;

/// Lifecycle

    public function new() {

        super();

        transparent = false;

        tabFocus = new TabFocus();

        autorun(updateStyle);

    }

/// Internal

    function updateStyle() {

        var theme = context.theme;

        color = theme.mediumBackgroundColor;
        itemSpacing = theme.formItemSpacing;
        padding(theme.formPadding);

    }

}

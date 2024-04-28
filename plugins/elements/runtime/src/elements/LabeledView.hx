package elements;

import ceramic.Click;
import ceramic.RowLayout;
import ceramic.TextView;
import ceramic.View;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using ceramic.Extensions;

class LabeledView<T:View> extends RowLayout implements Observable {

    @observe public var theme:Theme = null;

/// Public properties

    @observe public var label:String = '';

    @observe public var disabled:Bool = false;

    var containerView:RowLayout;

    var useContainer:Bool = false;

    public var view(default,set):T;
    function set_view(view:T):T {
        if (this.view == view)
            return view;
        if (this.view != null) {
            this.view.destroy();
        }
        this.view = view;
        if (view != null) {
            if (useContainer) {
                containerView.add(view);
            }
            else {
                add(view);
            }
            invalidateDisabled();
        }
        remove(labelText);
        add(labelText);
        return view;
    }

    public var labelPosition(default,set):LabelPosition = RIGHT;
    function set_labelPosition(labelPosition:LabelPosition):LabelPosition {
        if (this.labelPosition != labelPosition) {
            this.labelPosition = labelPosition;
            switch labelPosition {
                case LEFT:
                    remove(labelText);
                    remove(useContainer ? containerView : view);
                    add(labelText);
                    add(useContainer ? containerView : view);
                    if (containerView != null)
                        containerView.align = LEFT;
                    labelText.align = RIGHT;
                case RIGHT:
                    remove(labelText);
                    add(labelText);
                    if (containerView != null)
                        containerView.align = RIGHT;
                    labelText.align = LEFT;
            }
        }
        return labelPosition;
    }

    public var labelWidth(default,set):Float = 70;
    function set_labelWidth(labelWidth:Float):Float {
        if (this.labelWidth != labelWidth) {
            this.labelWidth = labelWidth;
            labelText.viewWidth = labelWidth;
        }
        return labelWidth;
    }

    public var labelViewWidth(get, set):Float;
    function get_labelViewWidth():Float {
        return labelText.viewWidth;
    }
    function set_labelViewWidth(labelViewWidth:Float):Float {
        return labelText.viewWidth = labelViewWidth;
    }

/// Internal properties

    var labelText:TextView;

/// Lifecycle

    public function new(view:T, useContainer:Bool = false) {

        super();

        itemSpacing = 6;

        labelText = new TextView();
        labelText.viewSize(labelWidth, auto());
        labelText.align = LEFT;
        labelText.verticalAlign = CENTER;
        labelText.pointSize = 12;
        labelText.preRenderedSize = 20;
        add(labelText);

        this.useContainer = useContainer;
        if (useContainer) {
            containerView = new RowLayout();
            containerView.transparent = true;
            containerView.viewSize(fill(), auto());
            containerView.align = RIGHT;
            add(containerView);
        }

        this.view = view;

        autorun(updateDisabled);
        autorun(updateLabel);
        autorun(updateStyle);

        // Focus view on label click
        #if !(ios || android)
        labelText.onPointerDown(this, _ -> handleLabelClick());
        #else
        var labelClick = new Click();
        labelText.component(labelClick);
        labelClick.onClick(this, handleLabelClick);
        #end

    }

/// Internal

    function handleLabelClick() {

        if (!disabled) {
            if (view is FieldView) {
                var field:FieldView = cast view;
                field.focus();
            }
        }

    }

    function updateLabel() {

        labelText.content = label;

    }

    function updateDisabled() {

        var view = this.view;
        unobserve();

        if (view != null) {
            var disabled = false;
            reobserve();
            if (view.getProperty('disabled')) {
                disabled = true;
            }
            unobserve();
            this.disabled = disabled;
        }
        else {
            this.disabled = false;
        }

        reobserve();

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (disabled) {
            labelText.textColor = theme.darkTextColor;
        }
        else {
            labelText.textColor = theme.lightTextColor;
        }

        labelText.font = theme.mediumFont;

    }

}

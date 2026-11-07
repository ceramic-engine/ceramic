// Ported from gpui-kit 0.8.1: crates/story/src/stories/dropdown_button_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.Action;
import gpui.Anchor;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Window;
import gpui.component.Size;
import gpui.component.button.Button;
import gpui.component.button.DropdownButton;
import gpui.component.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

enum DropdownButtonActionKind {
    Disabled;
    Loading;
    Selected;
    Compact;
    Shadow;
    ExportCsv;
    ExportPdf;
    SaveCopy;
    SaveTemplate;
    OpenQuarterlyReport;
    OpenWatchlistLayout;
}

/** Rust `enum ButtonAction` (an action). */
@:action(namespace = dropdown_button_story, noJson)
class DropdownButtonAction implements Action {
    public final value:DropdownButtonActionKind;
}

class DropdownButtonStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var disabled:Bool = false;

    var loading:Bool = false;

    var selected:Bool = false;

    var compact:Bool = false;

    var size:Size = Medium;

    var lastAction:String = 'Nothing yet';

    function new(cx:Context<DropdownButtonStory>) {
        super();
        focusHandle = cx.focusHandle();
    }

    public static function view(_:Window, cx:App):Entity<DropdownButtonStory> {
        return cx.newEntity((cx:Context<DropdownButtonStory>) -> new DropdownButtonStory(cx));
    }

    public static function title():String {
        return 'DropdownButton';
    }

    public static function description():String {
        return 'A button with an attached dropdown menu for additional options.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<DropdownButtonStory> = cast cx;
        final theme = Theme.global(cx);
        final disabled = this.disabled;
        final loading = this.loading;
        final selected = this.selected;
        final compact = this.compact;
        final view = self.entity();
        final shadow = theme.shadow;

        final exportButton = new Button('export-default')
            .label('Export')
            .onClick((_, _, cx) -> view.update(cx, (this_, cx) -> {
                this_.lastAction = 'Exported current view';
                cx.notify();
            }));
        if (this.compact) exportButton.compact();

        final saveButton = new Button('save-default')
            .label('Save')
            .tooltip('Save the current document');
        if (compact) saveButton.compact();
        saveButton.loading(loading)
            .onClick((_, _, cx) -> view.update(cx, (this_, cx) -> {
                this_.lastAction = 'Saved document';
                cx.notify();
            }));

        return vFlex()
            .gap6()
            .onAction(ChangeStorySize, self.listener((this_:DropdownButtonStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .onAction(DropdownButtonAction, self.listener((this_:DropdownButtonStory, action:DropdownButtonAction, window, cx) -> {
                switch action.value {
                    case Disabled: this_.disabled = !this_.disabled;
                    case Loading: this_.loading = !this_.loading;
                    case Selected: this_.selected = !this_.selected;
                    case Compact: this_.compact = !this_.compact;
                    case Shadow:
                        Theme.update(cx, theme -> theme.shadow = !theme.shadow);
                        window.refresh();
                    case ExportCsv: this_.lastAction = 'Exported as CSV';
                    case ExportPdf: this_.lastAction = 'Exported as PDF';
                    case SaveCopy: this_.lastAction = 'Saved as a new file';
                    case SaveTemplate: this_.lastAction = 'Saved as a template';
                    case OpenQuarterlyReport: this_.lastAction = 'Opened Quarterly Report.gpui';
                    case OpenWatchlistLayout: this_.lastAction = 'Opened Watchlist Layout.gpui';
                }
                cx.notify();
            }))
            .child(storyToolbar(size).dropdownChild(new Button('dropdown-button-options').label('Options'), (menu, _, _) -> menu
                .menuWithCheck('Disabled', disabled, new DropdownButtonAction(Disabled))
                .menuWithCheck('Loading', loading, new DropdownButtonAction(Loading))
                .menuWithCheck('Selected', selected, new DropdownButtonAction(Selected))
                .menuWithCheck('Compact', compact, new DropdownButtonAction(Compact))
                .menuWithCheck('Shadow', shadow, new DropdownButtonAction(Shadow))))
            .child(hFlex()
                .gap1()
                .textSm()
                .textColor(theme.mutedForeground)
                .child('Last action:')
                .child(lastAction))
            .child(section('Basic split').child(new DropdownButton('export')
                .withSize(size)
                .primary()
                .button(exportButton)
                .disabled(this.disabled)
                .selected(selected)
                .dropdownMenuWithAnchor(Anchor.TopRight, (menu, _, _) -> menu
                    .menu('Export all rows (.csv)', new DropdownButtonAction(ExportCsv))
                    .menu('Download report (.pdf)', new DropdownButtonAction(ExportPdf)))))
            .child(section('Inner button options').child(new DropdownButton('save')
                .withSize(size)
                .outline()
                .button(saveButton)
                .disabled(disabled)
                .dropdownMenu((menu, _, _) -> menu
                    .menu('Save as new file…', new DropdownButtonAction(SaveCopy))
                    .menu('Save as template…', new DropdownButtonAction(SaveTemplate)))))
            .child(section('Inherited styling').child(new DropdownButton('recent')
                .button(new Button('recent-default')
                    .label('Open latest')
                    .ghost()
                    .small()
                    .onClick((_, _, cx) -> view.update(cx, (this_, cx) -> {
                        this_.lastAction = 'Opened latest file';
                        cx.notify();
                    })))
                .selected(selected)
                .disabled(disabled)
                .dropdownMenu((menu, _, _) -> menu
                    .menu('Quarterly Report.gpui', new DropdownButtonAction(OpenQuarterlyReport))
                    .menu('Watchlist Layout.gpui', new DropdownButtonAction(OpenWatchlistLayout)))));
    }

}

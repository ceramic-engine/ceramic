// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (StorySection, section)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.AnyElement;
import glaze.App;
import glaze.Div;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.groupbox.GroupBox;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A titled section of a story (an outlined `GroupBox`), created with
 * `Lib.section(title)`. Styling and children apply to its content row.
 */
class StorySection implements RenderOnce implements Styled implements ParentElement {

    var base:Div;

    var titleValue:String;

    var descriptionValue:Null<String> = null;

    final subTitleElements:Array<AnyElement> = [];

    final childElements:Array<AnyElement> = [];

    public function new(title:String, base:Div) {
        this.titleValue = title;
        this.base = base;
    }

    public function description(description:String):StorySection {
        descriptionValue = description;
        return this;
    }

    public function subTitle(subTitle:IntoElement):StorySection {
        subTitleElements.push(subTitle);
        return this;
    }

    public function maxWMd():StorySection {
        base = base.maxW(rems(48.));
        return this;
    }

    public function maxWLg():StorySection {
        base = base.maxW(rems(64.));
        return this;
    }

    public function maxWXl():StorySection {
        base = base.maxW(rems(80.));
        return this;
    }

    public function maxW2xl():StorySection {
        base = base.maxW(rems(96.));
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):StorySection {
        childElements.push(child);
        return this;
    }

    public function children(children:Iterable<IntoElement>):StorySection {
        for (child in children) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final heading = vFlex()
            .minW0()
            .flex1()
            .gap1()
            .child(div().fontMedium().child(titleValue));
        if (descriptionValue != null) {
            heading.child(div().textXs().textColor(theme.mutedForeground).child(descriptionValue));
        }
        final titleRow = hFlex()
            .justifyBetween()
            .itemsStart()
            .wFull()
            .gap4()
            .child(heading);
        titleRow.extend(subTitleElements);

        base.extend(childElements);
        return new GroupBox()
            .id(titleValue)
            .outline()
            .mb6()
            .title(titleRow)
            .contentStyle(new StyleBuilder(new StyleRefinement())
                .rounded(theme.radiusLg)
                .overflowXHidden()
                .itemsCenter()
                .justifyCenter()
                .style())
            .child(base);
    }

}

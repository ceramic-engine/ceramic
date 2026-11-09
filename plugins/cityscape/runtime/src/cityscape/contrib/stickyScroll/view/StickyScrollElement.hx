// Ported from vscode src/vs/editor/contrib/stickyScroll/browser/stickyScrollElement.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.stickyScroll.view;

import cityscape.base.common.Uri;

class StickyRange {

    public final startLineNumber:Int;
    public final endLineNumber:Int;

    public function new(startLineNumber:Int, endLineNumber:Int) {
        this.startLineNumber = startLineNumber;
        this.endLineNumber = endLineNumber;
    }

}

class StickyElement {

    /**
     * Range of line numbers spanned by the current scope
     */
    public final range:Null<StickyRange>;

    /**
     * Must be sorted by start line number
     */
    public final children:Array<StickyElement>;

    /**
     * Parent sticky outline element
     */
    public final parent:Null<StickyElement>;

    public function new(range:Null<StickyRange>, children:Array<StickyElement>, parent:Null<StickyElement>) {
        this.range = range;
        this.children = children;
        this.parent = parent;
    }

}

class StickyModel {

    public final uri:Uri;
    public final version:Int;
    public final element:Null<StickyElement>;
    public final outlineProviderId:Null<String>;

    public function new(uri:Uri, version:Int, element:Null<StickyElement>, outlineProviderId:Null<String>) {
        this.uri = uri;
        this.version = version;
        this.element = element;
        this.outlineProviderId = outlineProviderId;
    }

}

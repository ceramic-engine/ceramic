// Ported from vscode src/vs/base/common/hierarchicalKind.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * A dotted kind (`refactor.extract`) that contains its sub kinds.
 */
class HierarchicalKind {

    public static inline final sep = '.';

    /**
     * Special kind that matches nothing
     */
    public static final None = new HierarchicalKind('@@none@@');
    public static final Empty = new HierarchicalKind('');

    public final value:String;

    public function new(value:String) {
        this.value = value;
    }

    public function equals(other:HierarchicalKind):Bool {
        return this.value == other.value;
    }

    public function contains(other:HierarchicalKind):Bool {
        return this.equals(other) || this.value == '' || StringTools.startsWith(other.value, this.value + HierarchicalKind.sep);
    }

    public function intersects(other:HierarchicalKind):Bool {
        return this.contains(other) || other.contains(this);
    }

    public function append(...parts:String):HierarchicalKind {
        final all:Array<String> = this.value.length > 0 ? [this.value] : [];
        for (p in parts) {
            all.push(p);
        }
        return new HierarchicalKind(all.join(HierarchicalKind.sep));
    }

}

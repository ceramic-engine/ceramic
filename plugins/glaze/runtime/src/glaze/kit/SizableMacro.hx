// Ported from gpui-kit 0.8.1: crates/component/src/sizing.rs (default methods of Sizable)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Adds the default methods of Rust's `Sizable` to the implementing class:
 * `xsmall()`, `small()`, `large()` (calling its `withSize`), `setSize()`
 * when missing, and `prepareForToolbar()` when missing.
 */
class SizableMacro {

    #if macro
    public static function build():Array<Field> {
        final fields = Context.getBuildFields();
        final localClass = Context.getLocalClass().get();
        if (localClass.isInterface)
            return null;
        final pos = Context.currentPos();

        final existing = new Map<String, Bool>();
        for (field in fields) existing.set(field.name, true);

        // Only once per hierarchy
        var parent = localClass.superClass;
        while (parent != null) {
            final parentClass = parent.t.get();
            for (iface in parentClass.interfaces) {
                if (iface.t.get().name == 'Sizable')
                    return null;
            }
            parent = parentClass.superClass;
        }

        final moduleName = localClass.module.split('.').pop();
        final selfType:ComplexType = TPath({
            pack: localClass.pack,
            name: moduleName,
            sub: moduleName == localClass.name ? null : localClass.name,
            params: [for (param in localClass.params) TPType(TPath({pack: [], name: param.name}))]
        });

        function add(name:String, expr:Expr, ret:ComplexType, ?args:Array<FunctionArg>, ?doc:String):Void {
            if (existing.exists(name))
                return;
            fields.push({
                name: name,
                doc: doc,
                access: [APublic, AInline],
                kind: FFun({args: args != null ? args : [], ret: ret, expr: expr}),
                pos: pos
            });
        }

        add('xsmall', macro return this.withSize(glaze.kit.Size.XSmall), selfType, 'Set to `Size.XSmall`.');
        add('small', macro return this.withSize(glaze.kit.Size.Small), selfType, 'Set to `Size.Small`.');
        add('large', macro return this.withSize(glaze.kit.Size.Large), selfType, 'Set to `Size.Large`.');
        add('prepareForToolbar', macro return this, selfType,
            'Apply control-specific presentation when this element is hosted by a toolbar (default: unchanged).');
        if (!existing.exists('setSize')) {
            fields.push({
                name: 'setSize',
                access: [APublic],
                kind: FFun({args: [{name: 'size', type: macro :glaze.kit.Size}], ret: macro :Void, expr: macro this.withSize(size)}),
                pos: pos
            });
        }

        return fields;
    }
    #end

}

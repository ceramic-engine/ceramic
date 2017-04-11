package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class EventsMacro {

    macro static public function build():Array<Field> {
        var fields = Context.getBuildFields();

        // Check class fields
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        // Also check parent fields
        var parentHold = Context.getLocalClass().get().superClass;
        var parent = parentHold != null ? parentHold.t : null;
        while (parent != null) {

            for (field in parent.get().fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
        }

        var newFields = [];

        for (field in fields) {
            if (hasEventMeta(field)) {
                switch (field.kind) {
                    case FieldType.FFun(fn):

                        if (field.access.indexOf(AStatic) != -1) {
                            throw new Error("Event cannot be static", field.pos);
                        }

                        var hasPrivateModifier = false;
                        if (field.access.indexOf(APrivate) != -1) {
                            hasPrivateModifier = true;
                        }

                        var hasPublicModifier = false;
                        if (field.access.indexOf(APublic) != -1) {
                            hasPublicModifier = true;
                        }

                        var handlerName = 'handle' + [for (arg in fn.args) arg.name.substr(0,1).toUpperCase() + arg.name.substr(1)].join('');
                        var handlerType = TFunction([for (arg in fn.args) arg.type], macro :Void);
                        var handlerCallArgs = [for (arg in fn.args) macro $i{arg.name}];
                        var capitalName = field.name.substr(0,1).toUpperCase() + field.name.substr(1);
                        var cbOnArray = '__cbOn' + capitalName;
                        var cbOnceArray = '__cbOnce' + capitalName;
                        var fnWillEmit = 'willEmit' + capitalName;
                        var fnDidEmit = 'didEmit' + capitalName;

                        // Create __cbOn{Name}
                        var cbOnField = {
                            pos: field.pos,
                            name: cbOnArray,
                            kind: FVar(TPath({
                                name: 'Array',
                                pack: [],
                                params: [
                                    TPType(
                                        handlerType
                                    )
                                ]
                            })),
                            access: [APrivate],
                            doc: field.doc,
                            meta: [{
                                name: ':noCompletion',
                                params: [],
                                pos: field.pos
                            }]
                        };
                        newFields.push(cbOnField);

                        // Create __cbOnce{Name}
                        var cbOnceField = {
                            pos: field.pos,
                            name: cbOnceArray,
                            kind: FVar(TPath({
                                name: 'Array',
                                pack: [],
                                params: [
                                    TPType(
                                        handlerType
                                    )
                                ]
                            })),
                            access: [APrivate],
                            doc: field.doc,
                            meta: [{
                                name: ':noCompletion',
                                params: [],
                                pos: field.pos
                            }]
                        };
                        newFields.push(cbOnceField);

                        // Create emit{Name}()
                        //
                        var willEmit = macro null;
                        if (fieldsByName.exists(fnWillEmit)) {
                            willEmit = macro this.$fnWillEmit($a{handlerCallArgs});
                        }

                        var didEmit = macro null;
                        if (fieldsByName.exists(fnDidEmit)) {
                            didEmit = macro this.$fnDidEmit($a{handlerCallArgs});
                        }

                        var emitField = {
                            pos: field.pos,
                            name: 'emit' + capitalName,
                            kind: FFun({
                                args: fn.args,
                                ret: macro :Void,
                                expr: macro {
                                    $willEmit;
                                    var len = 0;
                                    if (this.$cbOnArray != null) len += this.$cbOnArray.length;
                                    if (this.$cbOnceArray != null) len += this.$cbOnceArray.length;
                                    if (len > 0) {
                                        var callbacks = new haxe.ds.Vector<$handlerType>(len);
                                        var i = 0;
                                        if (this.$cbOnArray != null) {
                                            for (item in this.$cbOnArray) {
                                                callbacks.set(i, item);
                                                i++;
                                            }
                                        }
                                        if (this.$cbOnceArray != null) {
                                            for (item in this.$cbOnceArray) {
                                                callbacks.set(i, item);
                                                i++;
                                            }
                                            this.$cbOnceArray = null;
                                        }
                                        for (i in 0...len) {
                                            callbacks.get(i)($a{handlerCallArgs});
                                        }
                                        callbacks = null;
                                    }
                                    $didEmit;
                                }
                            }),
                            access: [hasPublicModifier ? APublic : APrivate],
                            doc: field.doc,
                            meta: hasPrivateModifier ? [{
                                name: ':noCompletion',
                                params: [],
                                pos: field.pos
                            }] : []
                        };
                        newFields.push(emitField);

                        // Create on{Name}()
                        var onField = {
                            pos: field.pos,
                            name: 'on' + capitalName,
                            kind: FFun({
                                args: [
                                    {
                                        name: handlerName,
                                        type: handlerType
                                    }
                                ],
                                ret: macro :Void,
                                expr: macro {
                                    if (this.$cbOnArray == null) {
                                        this.$cbOnArray = [];
                                    }
                                    this.$cbOnArray.push($i{handlerName});
                                }
                            }),
                            access: [hasPrivateModifier ? APrivate : APublic],
                            doc: field.doc,
                            meta: []
                        };
                        newFields.push(onField);

                        // Create once{Name}()
                        var onceField = {
                            pos: field.pos,
                            name: 'once' + capitalName,
                            kind: FFun({
                                args: [
                                    {
                                        name: handlerName,
                                        type: handlerType
                                    }
                                ],
                                ret: macro :Void,
                                expr: macro {
                                    if (this.$cbOnceArray == null) {
                                        this.$cbOnceArray = [];
                                    }
                                    this.$cbOnceArray.push($i{handlerName});
                                }
                            }),
                            access: [hasPrivateModifier ? APrivate : APublic],
                            doc: field.doc,
                            meta: []
                        };
                        newFields.push(onceField);

                        // Create off{Name}()
                        var offField = {
                            pos: field.pos,
                            name: 'off' + capitalName,
                            kind: FFun({
                                args: [
                                    {
                                        name: handlerName,
                                        type: handlerType,
                                        opt: true
                                    }
                                ],
                                ret: macro :Void,
                                expr: macro {
                                    if ($i{handlerName} != null) {
                                        if (this.$cbOnArray != null) {
                                            this.$cbOnArray.remove($i{handlerName});
                                        }
                                        if (this.$cbOnceArray != null) {
                                            this.$cbOnceArray.remove($i{handlerName});
                                        }
                                    } else {
                                        this.$cbOnArray = null;
                                        this.$cbOnceArray = null;
                                    }
                                }
                            }),
                            access: [hasPrivateModifier ? APrivate : APublic],
                            doc: field.doc,
                            meta: []
                        };
                        newFields.push(offField);

                    default:
                        throw new Error("Invalid event syntax", field.pos);
                }
            }
            else {
                // Keep field
                newFields.push(field);
            }
        }

        return newFields;

    } //build

    static function hasEventMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'event' || meta.name == ':event') {
                return true;
            }
        }

        return false;

    } //hasEventMeta

    static function isEmpty(expr:Expr) {

        if (expr == null) return true;

        return switch (expr.expr) {
            case ExprDef.EBlock(exprs): exprs.length == 0;
            default: false;
        }

    } //isEmpty

}

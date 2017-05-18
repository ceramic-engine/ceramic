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
                createEventFields(field, newFields, fieldsByName);
            }
            else {
                // Keep field
                newFields.push(field);
            }
        }

        return newFields;

    } //build

    @:allow(ceramic.macros.ObservableMacro)
    static function createEventFields(field:Field, newFields:Array<Field>, fieldsByName:Map<String,Bool>):Void {

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
                var onName = 'on' + capitalName;
                var onceName = 'once' + capitalName;
                var offName = 'off' + capitalName;
                var emitName = 'emit' + capitalName;
                var cbOnArray = '__cbOn' + capitalName;
                var cbOnceArray = '__cbOnce' + capitalName;
                var cbOnOwnerUnbindArray = '__cbOnOwnerUnbind' + capitalName;
                var cbOnceOwnerUnbindArray = '__cbOnceOwnerUnbind' + capitalName;
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

                // Create __cbOnOwnerUnbind{Name}
                var cbOnOwnerUnbindField = {
                    pos: field.pos,
                    name: cbOnOwnerUnbindArray,
                    kind: FVar(TPath({
                        name: 'Array',
                        pack: [],
                        params: [
                            TPType(
                                macro :Void->Void
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
                newFields.push(cbOnOwnerUnbindField);

                // Create __cbOnceOwnerUnbind{Name}
                var cbOnceOwnerUnbindField = {
                    pos: field.pos,
                    name: cbOnceOwnerUnbindArray,
                    kind: FVar(TPath({
                        name: 'Array',
                        pack: [],
                        params: [
                            TPType(
                                macro :Void->Void
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
                newFields.push(cbOnceOwnerUnbindField);

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
                    name: emitName,
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
                    name: onName,
                    kind: FFun({
                        args: [
                            {
                                name: 'owner',
                                type: macro :ceramic.Entity,
                                opt: true
                            },
                            {
                                name: handlerName,
                                type: handlerType
                            }
                        ],
                        ret: macro :Void,
                        expr: macro {
                            // Map owner to handler
                            if (owner != null) {
                                if (owner.destroyed) {
                                    return;
                                }
                                var destroyCb = function() {
                                    this.$offName($i{handlerName});
                                };
                                owner.onceDestroy(null, destroyCb);
                                if (this.$cbOnOwnerUnbindArray == null) {
                                    this.$cbOnOwnerUnbindArray = [];
                                }
                                this.$cbOnOwnerUnbindArray.push(function() {
                                    owner.offDestroy(destroyCb);
                                });
                            } else {
                                if (this.$cbOnOwnerUnbindArray == null) {
                                    this.$cbOnOwnerUnbindArray = [];
                                }
                                this.$cbOnOwnerUnbindArray.push(null);
                            }

                            // Add handler
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
                    name: onceName,
                    kind: FFun({
                        args: [
                            {
                                name: 'owner',
                                type: macro :ceramic.Entity,
                                opt: true
                            },
                            {
                                name: handlerName,
                                type: handlerType
                            }
                        ],
                        ret: macro :Void,
                        expr: macro {
                            // Map owner to handler
                            if (owner != null) {
                                if (owner.destroyed) {
                                    return;
                                }
                                var destroyCb = function() {
                                    this.$offName($i{handlerName});
                                };
                                owner.onceDestroy(null, destroyCb);
                                if (this.$cbOnceOwnerUnbindArray == null) {
                                    this.$cbOnceOwnerUnbindArray = [];
                                }
                                this.$cbOnceOwnerUnbindArray.push(function() {
                                    owner.offDestroy(destroyCb);
                                });
                            } else {
                                if (this.$cbOnceOwnerUnbindArray == null) {
                                    this.$cbOnceOwnerUnbindArray = [];
                                }
                                this.$cbOnceOwnerUnbindArray.push(null);
                            }

                            // Add handler
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
                    name: offName,
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
                                var index:Int;
                                var unbind:Void->Void;
                                if (this.$cbOnArray != null) {
                                    index = this.$cbOnArray.indexOf($i{handlerName});
                                    if (index != -1) {
                                        this.$cbOnArray.splice(index, 1);
                                        unbind = this.$cbOnOwnerUnbindArray[index];
                                        if (unbind != null) unbind();
                                        this.$cbOnOwnerUnbindArray.splice(index, 1);
                                    }
                                }
                                if (this.$cbOnceArray != null) {
                                    index = this.$cbOnceArray.indexOf($i{handlerName});
                                    if (index != -1) {
                                        this.$cbOnceArray.splice(index, 1);
                                        unbind = this.$cbOnceOwnerUnbindArray[index];
                                        if (unbind != null) unbind();
                                        this.$cbOnceOwnerUnbindArray.splice(index, 1);
                                    }
                                }
                            } else {
                                for (unbind in this.$cbOnOwnerUnbindArray) {
                                    if (unbind != null) unbind();
                                }
                                this.$cbOnOwnerUnbindArray = null;
                                for (unbind in this.$cbOnceOwnerUnbindArray) {
                                    if (unbind != null) unbind();
                                }
                                this.$cbOnceOwnerUnbindArray = null;
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

    } //createEventFields

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

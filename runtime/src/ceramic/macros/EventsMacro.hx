package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

using StringTools;

class EventsMacro {

    macro static public function build():Array<Field> {
        var fields = Context.getBuildFields();

        // Gather all emit{EventName}
        var allEmits:Map<String,Bool> = new Map();

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

                if (field.name.startsWith('emit')) {
                    allEmits.set(field.name.substring(4), true);
                }
                else if (field.meta.has('event')) {
                    allEmits.set(field.name.charAt(0).toUpperCase() + field.name.substring(1), true);
                }
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

        for (field in newFields) {
            if (field.name.startsWith('emit')) {
                allEmits.set(field.name.substring(4), true);
            }
        }

        // Check that {will|did}Emit{EventName} match an existing event
        for (field in newFields) {
            if (field.name.startsWith('willEmit')) {
                if (!allEmits.exists(field.name.substring(8))) {
                    throw new Error("No event with name `" + field.name.charAt(8).toLowerCase() + field.name.substring(9) + "` will ever be emitted by this class", field.pos);
                }
            }
            else if (field.name.startsWith('didEmit')) {
                if (!allEmits.exists(field.name.substring(7))) {
                    throw new Error("No event with name `" + field.name.charAt(7).toLowerCase() + field.name.substring(8) + "` will ever be emitted by this class", field.pos);
                }
            }
        }

        return newFields;

    } //build

    @:allow(ceramic.macros.ObservableMacro)
    @:allow(ceramic.macros.SerializableMacro)
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
                var sanitizedName = field.name;
                while (sanitizedName.startsWith('_')) sanitizedName = sanitizedName.substr(1);
                while (sanitizedName.endsWith('_')) sanitizedName = sanitizedName.substr(0, sanitizedName.length - 1);
                var capitalName = sanitizedName.substr(0,1).toUpperCase() + sanitizedName.substr(1);
                var onName = 'on' + capitalName;
                var onceName = 'once' + capitalName;
                var offName = 'off' + capitalName;
                var emitName = 'emit' + capitalName;
                var listensName = 'listens' + capitalName;
                var doc = field.doc;
                var origDoc = field.doc;
                if (doc == null || doc == '') {
                    doc = sanitizedName + ' event';
                }

#if (!display && !completion)
                var cbOnArray = '__cbOn' + capitalName;
                var cbOnceArray = '__cbOnce' + capitalName;
                var cbOnOwnerUnbindArray = '__cbOnOwnerUnbind' + capitalName;
                var cbOnceOwnerUnbindArray = '__cbOnceOwnerUnbind' + capitalName;

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
                    doc: doc,
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
                    doc: doc,
                    meta: [{
                        name: ':noCompletion',
                        params: [],
                        pos: field.pos
                    }]
                };
                newFields.push(cbOnceField);

#if ceramic_debug_events
                var cbOnPosArray = '__cbOnPos' + capitalName;
                var cbOncePosArray = '__cbOncePos' + capitalName;

                // Create __cbOnPos{Name}
                var cbOnPosField = {
                    pos: field.pos,
                    name: cbOnPosArray,
                    kind: FVar(TPath({
                        name: 'Array',
                        pack: [],
                        params: [
                            TPType(
                                macro :haxe.PosInfos
                            )
                        ]
                    })),
                    access: [APrivate],
                    doc: doc,
                    meta: [{
                        name: ':noCompletion',
                        params: [],
                        pos: field.pos
                    }]
                };
                newFields.push(cbOnPosField);

                // Create __cbOncePos{Name}
                var cbOncePosField = {
                    pos: field.pos,
                    name: cbOncePosArray,
                    kind: FVar(TPath({
                        name: 'Array',
                        pack: [],
                        params: [
                            TPType(
                                macro :haxe.PosInfos
                            )
                        ]
                    })),
                    access: [APrivate],
                    doc: doc,
                    meta: [{
                        name: ':noCompletion',
                        params: [],
                        pos: field.pos
                    }]
                };
                newFields.push(cbOncePosField);
#end

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
                    doc: doc,
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
                    doc: doc,
                    meta: [{
                        name: ':noCompletion',
                        params: [],
                        pos: field.pos
                    }]
                };
                newFields.push(cbOnceOwnerUnbindField);

                // Create emit{Name}()
                //
                var fnWillEmit = 'willEmit' + capitalName;
                var fnDidEmit = 'didEmit' + capitalName;

                var willEmit = macro null;
                if (fieldsByName.exists(fnWillEmit)) {
                    willEmit = macro this.$fnWillEmit($a{handlerCallArgs});
                }

                var didEmit = macro null;
                if (fieldsByName.exists(fnDidEmit)) {
                    didEmit = macro this.$fnDidEmit($a{handlerCallArgs});
                }
#end

                var emitField = {
                    pos: field.pos,
                    name: emitName,
                    kind: FFun({
                        args: fn.args,
                        ret: macro :Void,
#if (!display && !completion)
                        expr: macro {
                            $willEmit;
                            var len = 0;
                            if (this.$cbOnArray != null) len += this.$cbOnArray.length;
                            if (this.$cbOnceArray != null) len += this.$cbOnceArray.length;
                            if (len > 0) {
                                // TODO avoid allocation here while still keeping this safe?
                                // Some recycling of Vector objects could probably be done here
                                //var callbacks = new haxe.ds.Vector<$handlerType>(len);
                                var pool = ceramic.ArrayPool.pool(len);
                                var callbacks = pool.get();
                                #if ceramic_debug_events
                                var callbacksPos = [];
                                #end
                                var i = 0;
                                if (this.$cbOnArray != null) {
                                    for (ii in 0...this.$cbOnArray.length) {
                                        #if ceramic_debug_events
                                        callbacksPos.push(this.$cbOnPosArray[ii]);
                                        #end
                                        callbacks.set(i, this.$cbOnArray[ii]);
                                        i++;
                                    }
                                }
                                if (this.$cbOnceArray != null) {
                                    for (ii in 0...this.$cbOnceArray.length) {
                                        #if ceramic_debug_events
                                        callbacksPos.push(this.$cbOncePosArray[ii]);
                                        #end
                                        callbacks.set(i, this.$cbOnceArray[ii]);
                                        i++;
                                    }
                                    this.$cbOnceArray = null;
                                }
                                for (i in 0...len) {
                                    #if ceramic_debug_events
                                    haxe.Log.trace($v{emitName}, callbacksPos[i]);
                                    #end
                                    callbacks.get(i)($a{handlerCallArgs});
                                }
                                pool.release(callbacks);
                                callbacks = null;
                            }
                            $didEmit;
                        }
#else
                        expr: macro {}
#end
                    }),
                    access: [hasPublicModifier ? APublic : APrivate],
                    doc: doc,
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
                            #if ceramic_debug_events
                            ,{
                                name: 'pos',
                                type: macro :haxe.PosInfos,
                                opt: true
                            }
                            #end
                        ],
                        ret: macro :Void,
#if (!display && !completion)
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
                            #if ceramic_debug_events
                            if (this.$cbOnPosArray == null) {
                                this.$cbOnPosArray = [];
                            }
                            this.$cbOnPosArray.push(pos);
                            #end
                            if (this.$cbOnArray == null) {
                                this.$cbOnArray = [];
                            }
                            this.$cbOnArray.push($i{handlerName});
                        }
#else
                        expr: macro {}
#end
                    }),
                    access: [hasPrivateModifier ? APrivate : APublic],
                    doc: doc,
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
                            #if ceramic_debug_events
                            ,{
                                name: 'pos',
                                type: macro :haxe.PosInfos,
                                opt: true
                            }
                            #end
                        ],
                        ret: macro :Void,
#if (!display && !completion)
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
                            #if ceramic_debug_events
                            if (this.$cbOncePosArray == null) {
                                this.$cbOncePosArray = [];
                            }
                            this.$cbOncePosArray.push(pos);
                            #end
                            if (this.$cbOnceArray == null) {
                                this.$cbOnceArray = [];
                            }
                            this.$cbOnceArray.push($i{handlerName});
                        }
#else
                        expr: macro {}
#end
                    }),
                    access: [hasPrivateModifier ? APrivate : APublic],
                    doc: doc,
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
#if (!display && !completion)
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
#else
                        expr: macro {}
#end
                    }),
                    access: [hasPrivateModifier ? APrivate : APublic],
                    doc: doc,
                    meta: []
                };
                newFields.push(offField);

                // Create listens{Name}()
                var listensField = {
                    pos: field.pos,
                    name: listensName,
                    kind: FFun({
                        args: [],
                        ret: macro :Bool,
#if (!display && !completion)
                        expr: macro {
                            return (this.$cbOnArray != null && this.$cbOnArray.length > 0)
                                || (this.$cbOnceArray != null && this.$cbOnceArray.length > 0);
                        }
#else
                        expr: macro {
                            return false;
                        }
#end
                    }),
                    access: [hasPrivateModifier ? APrivate : APublic, AInline],
                    doc: origDoc != doc ? 'Does it listen to ' + doc : doc,
                    meta: []
                };
                newFields.push(listensField);

            default:
                throw new Error("Invalid event syntax", field.pos);
        }

    } //createEventFields

    static function hasEventMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'event') {
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

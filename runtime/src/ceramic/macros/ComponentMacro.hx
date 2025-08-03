package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Build macro for the Component interface that handles entity binding.
 * This macro automatically generates the necessary fields and methods to properly
 * implement the Component pattern in Ceramic.
 * 
 * Key features:
 * - Automatically adds an 'entity' field if not explicitly defined
 * - Generates setEntity() and getEntity() methods for proper entity binding
 * - Supports multiple entity properties with @entity metadata
 * - Ensures components inherit from ceramic.Entity
 * - Handles type-safe casting of entity properties
 * 
 * Entity properties can be defined in two ways:
 * 1. A field named 'entity' (automatically recognized)
 * 2. Any field with @entity metadata
 * 
 * The macro ensures that when a component is added to an entity,
 * all entity properties are properly set with type checking.
 */
class ComponentMacro {

    #if (haxe_ver < 4)
    /**
     * Flag to track if macro context reuse handler is registered (Haxe 3 compatibility).
     */
    static var onReused:Bool = false;
    #end

    /**
     * Cache of processed classes to avoid redundant processing.
     */
    static var processed = new Map<String,Bool>();

    /**
     * Build macro that processes Component implementations.
     * Adds required fields and methods for proper entity binding:
     * - entity field(s) for storing reference to owner entity
     * - setEntity() for binding component to entity with type checking
     * - getEntity() for retrieving the owner entity
     * - initializerName for component factory registration
     * 
     * @return Modified fields array with component infrastructure
     */
    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN ComponentMacro.build()');
        #end

        #if (haxe_ver < 4)
        if (!onReused) {
            onReused = true;
            Context.onMacroContextReused(function() {
                processed = new Map();
                return true;
            });
        }
        #end

        var fields = Context.getBuildFields();
        var localClass = Context.getLocalClass().get();
        var classPath = Context.getLocalClass().toString();

        // Only transform fields on classes that directly implement Component interface
        var interfaces = localClass.interfaces;
        var directlyImplementsComponent = false;
        for (anInterface in interfaces) {
            if (anInterface.t.toString() == 'ceramic.Component') {
                directlyImplementsComponent = true;
                break;
            }
        }
        if (!directlyImplementsComponent) {
            // Not a direct interface implementatio,
            // just check if there are new fields that can be used as entity
            var entityFields:Array<Field> = [];
            var setEntityField:Field = null;
            var getEntityField:Field = null;
            for (field in fields) {
                if (field.name == 'entity') {
                    entityFields.push(field);
                }
                else if (field.name == 'setEntity') {
                    setEntityField = field;
                }
                else if (field.name == 'getEntity') {
                    getEntityField = field;
                }
                else {
                    var hasEntityMeta = false;
                    if (field.meta != null) {
                        for (aMeta in field.meta) {
                            if (aMeta.name == 'entity') {
                                hasEntityMeta = true;
                                break;
                            }
                        }
                    }
                    if (hasEntityMeta) {
                        entityFields.push(field);
                    }
                }
            }
            if (entityFields.length > 0) {

                for (entityField in entityFields) {

                    switch(entityField.kind) {
                        case FVar(type, expr) | FProp(_, _, type, expr):
                            if (entityField.access.indexOf(AStatic) != -1) {
                                Context.error("Entity property cannot be static", entityField.pos);
                                return fields;
                            }
                            if (entityField.access.indexOf(APrivate) == -1 && entityField.access.indexOf(APublic) == -1) {
                                entityField.access.push(APublic);
                            }
                        default:
                            Context.error("Invalid entity property", entityField.pos);
                            return fields;
                    }
                    var hasKeepMeta = false;
                    if (entityField.meta != null) {
                        for (aMeta in entityField.meta) {
                            if (aMeta.name == ':keep') {
                                hasKeepMeta = true;
                                break;
                            }
                        }
                    }
                    if (!hasKeepMeta) {
                        if (entityField.meta == null) entityField.meta = [];
                        entityField.meta.push({
                            name: ':keep',
                            params: [],
                            pos: entityField.pos
                        });
                    }
                }

                if (setEntityField == null) {
                    computeSetEntityField(fields, entityFields, true);
                }
                if (getEntityField == null) {
                    computeGetEntityField(fields, entityFields, true);
                }
            }

            return fields;
        }

        // Ensure that we inherit from ceramic.Entity
        var inheritsFromEntity = (classPath == 'ceramic.Entity');
        var parentHold = localClass.superClass;
        var parent = parentHold != null ? parentHold.t : null;
        var numParents = 0;
        while (parent != null) {

            if (!inheritsFromEntity && parentHold.t.toString() == 'ceramic.Entity') {
                inheritsFromEntity = true;
                break;
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
            numParents++;
        }
        if (!inheritsFromEntity) {
            Context.error("Class " + classPath + " implements ceramic.Component interface thus must inherit (directly or indirectly) from ceramic.Entity", Context.currentPos());
            return fields;
        }

        var hasInitializerNameField = false;
        var entityNamedField:Field = null;
        var entityFields:Array<Field> = [];
        var setEntityField:Field = null;
        var getEntityField:Field = null;
        for (field in fields) {

            if (entityNamedField == null) {
                if (field.name == 'entity') {
                    entityNamedField = field;
                    entityFields.push(field);
                }
            }

            if (setEntityField == null) {
                if (field.name == 'setEntity') {
                    setEntityField = field;
                }
            }
            if (getEntityField == null) {
                if (field.name == 'getEntity') {
                    getEntityField = field;
                }
            }

            var hasEntityMeta = false;
            if (field.meta != null) {
                for (aMeta in field.meta) {
                    if (aMeta.name == 'entity') {
                        hasEntityMeta = true;
                        break;
                    }
                }
            }
            if (hasEntityMeta) {
                entityFields.push(field);
            }

            if (!hasInitializerNameField && field.name == 'initializerName') {
                hasInitializerNameField = true;
            }
        }

        for (entityField in entityFields) {

            switch(entityField.kind) {
                case FVar(type, expr) | FProp(_, _, type, expr):
                    if (entityField.access.indexOf(AStatic) != -1) {
                        Context.error("Entity property cannot be static", entityField.pos);
                        return fields;
                    }
                    if (entityField.access.indexOf(APrivate) == -1 && entityField.access.indexOf(APublic) == -1) {
                        entityField.access.push(APublic);
                    }
                default:
                    Context.error("Invalid entity property", entityField.pos);
                    return fields;
            }
            var hasKeepMeta = false;
            if (entityField.meta != null) {
                for (aMeta in entityField.meta) {
                    if (aMeta.name == ':keep') {
                        hasKeepMeta = true;
                        break;
                    }
                }
            }
            if (!hasKeepMeta) {
                if (entityField.meta == null) entityField.meta = [];
                entityField.meta.push({
                    name: ':keep',
                    params: [],
                    pos: entityField.pos
                });
            }
        }

        if (entityFields.length == 0) {

            var field = {
                pos: Context.currentPos(),
                name: 'entity',
                kind: FVar(TPath({pack: ['ceramic'], name: 'Entity'})),
                access: [APublic],
                doc: '',
                meta: [{
                    name: ':keep',
                    params: [],
                    pos: Context.currentPos()
                }]
            };
            fields.push(field);
            entityFields.push(field);
        }

        if (setEntityField == null) {
            computeSetEntityField(fields, entityFields, false);
        }
        if (getEntityField == null) {
            computeGetEntityField(fields, entityFields, false);
        }

        if (!hasInitializerNameField) {

            var field = {
                pos: Context.currentPos(),
                name: 'initializerName',
                kind: FProp('default', 'null', TPath({pack: [], name: 'String'}), macro null),
                access: [APublic],
                doc: '',
                meta: []
            };
            fields.push(field);
        }

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END ComponentMacro.build()');
        #end

        return fields;

    }

    /**
     * Generates the setEntity() method implementation.
     * Creates type-safe setter that casts the entity parameter to the appropriate
     * type for each entity field. Supports multiple entity properties with
     * automatic type checking using Std.isOfType().
     * 
     * @param fields Array to add the generated method to
     * @param entityFields Entity properties that need to be set
     * @param callSuper Whether to call super.setEntity() (for subclasses)
     */
    static function computeSetEntityField(fields:Array<Field>, entityFields:Array<Field>, callSuper:Bool):Void {

        var setEntityExprs = [];
        setEntityExprs.push('{');
        if (callSuper) {
            setEntityExprs.push('super.setEntity(entity);');
        }
        #if (!display && !completion)
        for (entityField in entityFields) {
            var entityFieldName = entityField.name;
            var entityType:ComplexType = null;
            switch entityField.kind {
                default:
                case FVar(t, e):
                    entityType = t;
                case FProp(get, set, t, e):
                    entityType = t;
            }
            var strType = null;
            if (entityType != null) {
                switch entityType {
                    default:
                    case TPath(p):
                        strType = p.name;
                        if (p.pack.length > 0) {
                            strType = p.pack.join('.') + '.' + strType;
                        }
                }
            }
            if (strType != null) {
                setEntityExprs.push('if (Std.isOfType(entity, $strType))');
                setEntityExprs.push('    this.$entityFieldName = cast entity;');
                setEntityExprs.push('else');
                setEntityExprs.push('    this.$entityFieldName = null;');
            }
            else {
                setEntityExprs.push('this.$entityFieldName = cast entity;');
            }
        }
        #end
        setEntityExprs.push('}');
        fields.push({
            pos: Context.currentPos(),
            name: 'setEntity',
            kind: FFun({
                args: [{
                    name: 'entity',
                    type: macro :ceramic.Entity
                }],
                ret: macro :Void,
                expr: Context.parse(setEntityExprs.join('\n'), Context.currentPos())
            }),
            access: callSuper ? [APrivate, AOverride] : [APrivate],
            doc: '',
            meta: [{
                name: ':keep',
                params: [],
                pos: Context.currentPos()
            }]
        });

    }

    /**
     * Generates the getEntity() method implementation.
     * Returns the first entity field value, providing access to the
     * component's owner entity.
     * 
     * @param fields Array to add the generated method to
     * @param entityFields Entity properties to read from
     * @param callSuper Whether to call super.getEntity() (for subclasses)
     */
    static function computeGetEntityField(fields:Array<Field>, entityFields:Array<Field>, callSuper:Bool):Void {

        #if (!display && !completion)
        var entityFieldName:String = null;
        for (entityField in entityFields) {
            entityFieldName = entityField.name;
            break;
        }
        #end
        var getEntityExprs = [];
        getEntityExprs.push('{');
        #if (!display && !completion)
        getEntityExprs.push('return this.$entityFieldName;');
        #else
        getEntityExprs.push('return null;');
        #end
        getEntityExprs.push('}');
        fields.push({
            pos: Context.currentPos(),
            name: 'getEntity',
            kind: FFun({
                args: [],
                ret: macro :ceramic.Entity,
                expr: Context.parse(getEntityExprs.join('\n'), Context.currentPos())
            }),
            access: callSuper ? [APrivate, AOverride] : [APrivate],
            doc: '',
            meta: [{
                name: ':keep',
                params: [],
                pos: Context.currentPos()
            }]
        });

    }

}

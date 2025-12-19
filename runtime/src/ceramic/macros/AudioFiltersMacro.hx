package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.TypeTools;

/**
 * Build macro for audio filters and worklets that generates parameter bindings and Web Audio API integration.
 * This macro handles the complex translation between Ceramic's audio filter system and the underlying
 * Web Audio API worklet architecture.
 *
 * For filters:
 * - Generates getter/setter properties for @param annotated fields
 * - Links filter parameters to worklet parameters
 * - Creates initialization code for default values
 *
 * For worklets:
 * - Processes @param metadata for Web Audio API parameter descriptors
 * - Generates optimized parameter accessors
 * - Handles platform-specific code generation
 *
 * On web platforms, this macro also tracks all filter and worklet references
 * for bundling and deployment.
 */
class AudioFiltersMacro {

    #if (macro && (web || ceramic_audio_filters_collect_info))
    /**
     * Collects all audio filter class references for web deployment.
     */
    @:persistent static var filterReferences:Array<{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }> = [];

    /**
     * Collects all audio worklet class references for web deployment.
     */
    @:persistent static var workletReferences:Array<{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }> = [];

    /**
     * Cache of file content hashes to avoid redundant file reads.
     */
    @:persistent static var fileHashes:Map<String,String> = new Map();

    /**
     * Computes or retrieves cached MD5 hash of a file's content.
     * @param filePath Path to the file to hash
     * @return MD5 hash string
     */
    static function getHash(filePath:String):String {
        var hash = fileHashes.get(filePath);
        if (hash == null) {
            hash = haxe.crypto.Md5.encode(sys.io.File.getContent(filePath));
            fileHashes.set(filePath, hash);
        }
        return hash;
    }

    /**
     * Registers a filter reference if not already present.
     * Checks for existing entry with same pack and name to avoid duplicates.
     */
    static function addFilterReference(ref:{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }):Void {
        for (existing in filterReferences) {
            if (existing.name == ref.name && arraysEqual(existing.pack, ref.pack)) {
                if (existing.hash != ref.hash) {
                    existing.filePath = ref.filePath;
                    existing.hash = ref.hash;
                    existing.min = ref.min;
                    existing.max = ref.max;
                }
                return;
            }
        }
        filterReferences.push(ref);
    }

    /**
     * Registers a worklet reference if not already present.
     * Checks for existing entry with same pack and name to avoid duplicates.
     */
    static function addWorkletReference(ref:{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }):Void {
        for (existing in workletReferences) {
            if (existing.name == ref.name && arraysEqual(existing.pack, ref.pack)) {
                if (existing.hash != ref.hash) {
                    existing.filePath = ref.filePath;
                    existing.hash = ref.hash;
                    existing.min = ref.min;
                    existing.max = ref.max;
                }
                return;
            }
        }
        workletReferences.push(ref);
    }

    /**
     * Compares two string arrays for equality.
     */
    static function arraysEqual(a:Array<String>, b:Array<String>):Bool {
        if (a == null && b == null) return true;
        if (a == null || b == null) return false;
        if (a.length != b.length) return false;
        for (i in 0...a.length) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }
    #end

    /**
     * Initializes the audio filters macro system.
     * On web platforms, registers a post-generation hook to output
     * filter and worklet metadata for the build system.
     */
    public static function init():Void {

        #if (web || ceramic_audio_filters_collect_info)
        var isCompletion = Context.defined('completion');
        if (!isCompletion) {
            Context.onAfterGenerate(function() {
                var targetPath = DefinesMacro.jsonDefinedValue('target_path');
                if (targetPath != null) {
                    filterReferences.sort(function(a, b) {
                        if (a.filePath < b.filePath) return -1;
                        if (a.filePath > b.filePath) return 1;
                        if (a.hash < b.hash) return -1;
                        if (a.hash > b.hash) return 1;
                        return 0;
                    });
                    workletReferences.sort(function(a, b) {
                        if (a.filePath < b.filePath) return -1;
                        if (a.filePath > b.filePath) return 1;
                        if (a.hash < b.hash) return -1;
                        if (a.hash > b.hash) return 1;
                        return 0;
                    });
                    if (!sys.FileSystem.exists(haxe.io.Path.join([targetPath, 'audio-filters']))) {
                        sys.FileSystem.createDirectory(haxe.io.Path.join([targetPath, 'audio-filters']));
                    }
                    sys.io.File.saveContent(haxe.io.Path.join([targetPath, 'audio-filters', 'info.json']), haxe.Json.stringify({
                        filters: filterReferences,
                        worklets: workletReferences
                    }));
                }
            });
        }
        #end

    }

    /**
     * Build macro for AudioFilter subclasses.
     * Generates parameter accessors and links to the associated worklet class.
     * On web platforms, also tracks the filter for deployment.
     *
     * @return Modified fields with parameter properties and initialization
     */
    macro static public function buildFilter():Array<Field> {

        #if (web && ceramic_build_audio_worklets && !completion && !display)
        return [];
        #elseif ((web || ceramic_audio_filters_collect_info) && !completion && !display)
        final classRef = Context.getLocalClass().get();
        final classPos = Context.getPosInfos(classRef.pos);
        var filePath = Context.getPosInfos(Context.currentPos()).file;
        if (!Path.isAbsolute(filePath)) {
            filePath = Path.join([Sys.getCwd(), filePath]);
        }
        addFilterReference({
            pack: [].concat(classRef.pack ?? []),
            name: classRef.name,
            filePath: filePath,
            hash: getHash(filePath),
            min: classPos.min,
            max: classPos.max
        });
        return processFilterParams(Context.getBuildFields());
        #else
        return processFilterParams(Context.getBuildFields());
        #end

    }

    /**
     * Build macro for AudioFilterWorklet subclasses.
     * Processes @param annotated fields to generate Web Audio API parameter descriptors.
     * On web platforms, modifies the process() method for platform-specific behavior.
     *
     * @return Modified fields with parameter getters and metadata
     */
    macro static public function buildWorklet():Array<Field> {

        #if (web && ceramic_build_audio_worklets)
        return processWorkletParams(Context.getBuildFields());
        #elseif web
        var fields:Array<Field> = [];
        for (field in Context.getBuildFields()) {
            if (field.name == 'process') {
                fields.push({
                    name: field.name,
                    meta: field.meta,
                    pos: field.pos,
                    kind: switch field.kind {
                        case FFun(f):
                            FFun({
                                args: f.args,
                                params: f.params,
                                expr: macro {},
                                ret: null
                            });
                        case _: field.kind;
                    },
                    access: field.access
                });
            }
            else if (fieldHasParamMeta(field)) {
                #if !(display || completion)
                switch field.kind {
                    case FVar(varType, e):
                        for (meta in field.meta) {
                            if (meta.name == 'param') {
                                meta.params = [e];
                            }
                        }
                    case _:
                }
                #end
                fields.push(field);
            }
        }
        final classRef = Context.getLocalClass().get();
        final classPos = Context.getPosInfos(classRef.pos);
        var filePath = Context.getPosInfos(Context.currentPos()).file;
        if (!Path.isAbsolute(filePath)) {
            filePath = Path.join([Sys.getCwd(), filePath]);
        }
        addWorkletReference({
            pack: [].concat(classRef.pack ?? []),
            name: classRef.name,
            filePath: filePath,
            hash: getHash(filePath),
            min: classPos.min,
            max: classPos.max
        });
        return fields;
        #elseif ceramic_audio_filters_collect_info
        final classRef = Context.getLocalClass().get();
        final classPos = Context.getPosInfos(classRef.pos);
        var filePath = Context.getPosInfos(Context.currentPos()).file;
        if (!Path.isAbsolute(filePath)) {
            filePath = Path.join([Sys.getCwd(), filePath]);
        }
        addWorkletReference({
            pack: [].concat(classRef.pack ?? []),
            name: classRef.name,
            filePath: filePath,
            hash: getHash(filePath),
            min: classPos.min,
            max: classPos.max
        });
        return processWorkletParams(Context.getBuildFields());
        #else
        return processWorkletParams(Context.getBuildFields());
        #end

    }

    /**
     * Processes filter class fields to generate parameter bindings.
     * Analyzes the workletClass() method to extract worklet parameters
     * and generates corresponding properties on the filter.
     *
     * @param fields Original class fields
     * @return Modified fields with parameter properties and initialization
     */
    static function processFilterParams(fields:Array<Field>):Array<Field> {

        var workletFields:Array<ClassField> = null;

        for (field in fields) {
            if (field.name == 'workletClass') {
                switch field.kind {
                    case FFun(f):
                        switch f.expr.expr {
                            case EReturn(e):
                                final complexType:ComplexType = exprToComplexType(e);
                                final type:Type = Context.resolveType(complexType, Context.currentPos());
                                switch type {
                                    case TInst(t, params):
                                        workletFields = t.get().fields.get();
                                    case _:
                                        throw new Error("workletClass() isn't returning a class type", field.pos);
                                }
                            case EBlock(exprs) if (exprs.length == 1):
                                switch exprs[0].expr {
                                    case EReturn(e):
                                        final complexType:ComplexType = exprToComplexType(e);
                                        final type:Type = Context.resolveType(complexType, Context.currentPos());
                                        switch type {
                                            case TInst(t, params):
                                                workletFields = t.get().fields.get();
                                            case _:
                                                throw new Error("workletClass() isn't returning a class type", field.pos);
                                        }
                                    case _:
                                        throw new Error("workletClass() should be in the format 'return YourFilterWorkletClass;'", field.pos);
                                }
                            case _:
                                throw new Error("workletClass() should be in the format 'return YourFilterWorkletClass;'", field.pos);
                        }
                    case _:
                        throw new Error("Invalid workletClass field", field.pos);
                }
            }
        }

        if (workletFields == null) {
            throw new Error("Failed to resolve worklet fields", Context.currentPos());
        }

        var paramIndex:Int = 0;
        var defaults:Array<String> = [];
        for (field in workletFields) {
            if (field.meta.has('param')) {
                switch field.kind {
                    case FVar(read, write):
                        final varType = TypeTools.toComplexType(field.type);
                        var defaultValExpr = null;
                        if (defaultValExpr == null) {
                            final fieldMeta = field.meta.get();
                            for (meta in fieldMeta) {
                                if (meta.name == 'param' && meta.params != null && meta.params.length > 0) {
                                    defaultValExpr = meta.params[0];
                                }
                            }
                        }
                        #if (display || completion)
                        fields.push({
                            name: field.name,
                            meta: field.meta.get(),
                            pos: field.pos,
                            doc: field.doc,
                            kind: FVar(varType, null),
                            access: [APublic]
                        });
                        #else
                        switch varType {
                            case TPath(p) if ((p.name == 'StdTypes' && (p.sub == 'Bool' || p.sub == 'Int' || p.sub == 'Float')) || p.name == 'Bool' || p.name == 'Int' || p.name == 'Float'):
                                final paramType:String = p.name == 'StdTypes' ? p.sub : p.name;
                                if (defaultValExpr != null) {
                                    defaults.push('${field.name} = ${new Printer().printExpr(defaultValExpr)};');
                                }
                                else {
                                    defaults.push('setFloat($paramIndex, 0);');
                                }
                                fields.push({
                                    name: field.name,
                                    meta: field.meta.get(),
                                    pos: field.pos,
                                    doc: field.doc,
                                    kind: FProp('get', 'set', varType, null),
                                    access: [APublic]
                                });
                                fields.push({
                                    name: 'get_' + field.name,
                                    pos: field.pos,
                                    kind: FFun({
                                        args: [],
                                        ret: varType,
                                        expr: Context.parse('{
                                            return get$paramType($paramIndex);
                                        }', Context.currentPos())
                                    }),
                                    access: [APrivate]
                                });
                                fields.push({
                                    name: 'set_' + field.name,
                                    pos: field.pos,
                                    kind: FFun({
                                        args: [{
                                            name: 'value',
                                            type: varType
                                        }],
                                        ret: varType,
                                        expr: Context.parse('{
                                            set$paramType($paramIndex, value);
                                            return value;
                                        }', Context.currentPos())
                                    }),
                                    access: [APrivate]
                                });
                                paramIndex++;
                            case _:
                                throw new Error("Invalid audio filter param type: " + varType, field.pos);
                        }
                        #end
                    case FMethod(k):
                        throw new Error("Invalid audio filter param", field.pos);
                }
            }
        }

        if (defaults.length > 0) {
            fields.push({
                name: '_initDefaultParamValues',
                pos: Context.currentPos(),
                kind: FFun({
                    args: [],
                    expr: Context.parse('{
                    acquireParams();
                    ' + defaults.join('
                    ') +
                    'releaseParams();
                    }', Context.currentPos())
                }),
                access: [AOverride]
            });
        }

        if (paramIndex > 0) {
            fields.push({
                name: 'numParams',
                pos: Context.currentPos(),
                kind: FFun({
                    args: [],
                    expr: macro return $v{paramIndex},
                    ret: macro :Int
                }),
                access: [AOverride]
            });
        }

        return fields;

    }

    /**
     * Processes worklet class fields to generate parameter accessors.
     * Converts @param annotated fields into getter properties that
     * read from the Web Audio API parameter arrays.
     *
     * @param fields Original class fields
     * @return Modified fields with parameter getters
     */
    static function processWorkletParams(fields:Array<Field>):Array<Field> {

        var paramIndex:Int = 0;
        for (field in fields) {
            if (fieldHasParamMeta(field)) {
                switch field.kind {
                    case FVar(varType, e):
                        #if (display || completion)
                        // Nothing to do in that case
                        #else
                        switch varType {
                            case TPath(p) if ((p.name == 'StdTypes' && (p.sub == 'Bool' || p.sub == 'Int' || p.sub == 'Float')) || p.name == 'Bool' || p.name == 'Int' || p.name == 'Float'):
                                final paramType:String = p.name == 'StdTypes' ? p.sub : p.name;
                                for (meta in field.meta) {
                                    if (meta.name == 'param') {
                                        meta.params = [e];
                                    }
                                }
                                field.kind = FProp('get', 'never', varType, null);
                                fields.push({
                                    name: 'get_' + field.name,
                                    pos: field.pos,
                                    kind: FFun({
                                        args: [],
                                        ret: varType,
                                        expr: Context.parse('{
                                            return get$paramType($paramIndex);
                                        }', Context.currentPos())
                                    }),
                                    access: [APrivate, AInline]
                                });
                                paramIndex++;
                            case _:
                                throw new Error("Invalid audio filter param type: " + varType, field.pos);
                        }
                        #end
                    case FProp(get, set, t, e):
                        throw new Error("Audio filter param cannot have custom getter or setter", field.pos);
                    case FFun(f):
                        throw new Error("Invalid audio filter param", field.pos);
                }
            }
        }

        if (paramIndex > 0) {
            fields.push({
                name: 'numParams',
                pos: Context.currentPos(),
                kind: FFun({
                    args: [],
                    expr: macro return $v{paramIndex},
                    ret: macro :Int
                }),
                access: [AOverride]
            });
        }

        return fields;

    }

    /**
     * Converts an expression to a ComplexType for type resolution.
     * Used to parse the return value of workletClass() methods.
     *
     * @param e Expression to convert
     * @return ComplexType representation
     */
    static function exprToComplexType(e:Expr):ComplexType {

        var printer = new Printer();
        var str = printer.printExpr(e);
        var pack = str.split('.');
        var name = pack.pop();
        return TPath({
            pack: pack,
            name: name
        });

    }

    /**
     * Checks if a field has the @param metadata annotation.
     * Fields with this annotation are exposed as audio parameters.
     *
     * @param field Field to check
     * @return True if field has @param metadata
     */
    static function fieldHasParamMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'param') {
                return true;
            }
        }

        return false;

    }

}
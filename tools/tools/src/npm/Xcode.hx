package npm;

@:jsRequire('xcode')
extern class Xcode {

    static function project(path:String):PbxProject;

} //Xcode

extern class PbxProject {

    var filepath(default,null):String;

    function parse(callback:String->Void):PbxProject;

    function parseSync():PbxProject;

    function writeSync():String;

    function allUuids():Array<String>;

    function generateUuid():String;

    function addPluginFile(path:String, ?opt:Dynamic):PbxFile;

    function removePluginFile(path:String, ?opt:Dynamic):Void;

    function addProductFile(path:String, ?opt:Dynamic):PbxFile;

    function removeProductFile(path:String, ?opt:Dynamic):PbxFile;

    function addSourceFile(path:String, ?opt:Dynamic, ?group:String):PbxFile;

    function removeSourceFile(path:String, ?opt:Dynamic, ?group:String):PbxFile;

    function addHeaderFile(path:String, ?opt:Dynamic, ?group:String):PbxFile;

    function removeHeaderFile(path:String, ?opt:Dynamic, ?group:String):PbxFile;

    function addResourceFile(path:String, ?opt:Dynamic, ?group:String):PbxFile;

    function removeResourceFile(path:String, ?opt:Dynamic, ?group:String):PbxFile;

    function addFramework(path:String, ?opt:Dynamic):PbxFile;

    function removeFramework(path:String, ?opt:Dynamic):PbxFile;

    function addCopyfile(path:String, ?opt:Dynamic):PbxFile;

    function pbxCopyfilesBuildPhaseObj(target:String):Dynamic;

    function addToPbxCopyfilesBuildPhase(file:PbxFile):Void;

    function removeCopyFile(path:String, ?opt:Dynamic):Void;

    function removeFromPbxCopyfilesBuildPhase(file:PbxFile):Void;

    function addStaticLibrary(path:String, ?opt:Dynamic):PbxFile;

    function addToPbxBuildFileSection(file:PbxFile):Void;

    function removeFromPbxBuildFileSection(file:PbxFile):Void;

    function addPbxGroup(filePathsArray:Array<String>, name:String, path:String, ?sourceTree:String):Void;

    function removePbxGroup(name:String):Void;

    function addToPbxProjectSection(target:Dynamic):Void;

    function addToPbxNativeTargetSection(target:Dynamic):Void;

    function addToPbxFileReferenceSection(file:PbxFile):Void;

    function removeFromPbxFileReferenceSection(file:PbxFile):PbxFile;

    function addToXcVersionGroupSection(file:PbxFile):Void;

    function addToPluginsPbxGroup(file:PbxFile):Void;

    function removeFromPluginsPbxGroup(file:PbxFile):Void;

    function addToResourcesPbxGroup(file:PbxFile):Void;

    function removeFromResourcesPbxGroup(file:PbxFile):Void;

    function addToFrameworksPbxGroup(file:PbxFile):Void;

    function removeFromFrameworksPbxGroup(file:PbxFile):Void;

    function addToPbxEmbedFrameworksBuildPhase(file:PbxFile):Void;

    function removeFromPbxEmbedFrameworksBuildPhase(file:PbxFile):Void;

    function addToProductsPbxGroup(file:PbxFile):Void;

    function removeFromProductsPbxGroup(file:PbxFile):Void;

    function addToPbxSourcesBuildPhase(file:PbxFile):Void;

    function removeFromPbxSourcesBuildPhase(file:PbxFile):Void;

    function addToPbxResourcesBuildPhase(file:PbxFile):Void;

    function removeFromPbxResourcesBuildPhase(file:PbxFile):Void;

    function addToPbxFrameworksBuildPhase(file:PbxFile):Void;

    function removeFromPbxFrameworksBuildPhase(file:PbxFile):Void;

    function addXCConfigurationList(configurationObjectsArray:Array<Dynamic>, defaultConfigurationName:String, comment:String):Dynamic;

    function addTargetDependency(target:String):Dynamic;

    function addBuildPhase(filePathsArray:Array<String>, buildPhaseType:String, comment:String, ?target:String, ?folderType:String, ?subfolderPath:String):Dynamic;

    function pbxProjectSection():Dynamic;

    function pbxBuildFileSection():Dynamic;

    function pbxXCBuildConfigurationSection():Dynamic;

    function pbxFileReferenceSection():Dynamic;

    function pbxNativeTargetSection():Dynamic;

    function xcVersionGroupSection():Dynamic;

    function pbxXCConfigurationList():Dynamic;

    function pbxGroupByName(name:String):Dynamic;

    function pbxTargetByName(name:String):Dynamic;

    function findTargetKey(name:String):String;

    function pbxItemByComment(name:String, pbxSectionName:String):String;

    function pbxSourcesBuildPhaseObj(target:Dynamic):Dynamic;

    function pbxResourcesBuildPhaseObj(target:Dynamic):Dynamic;

    function pbxFrameworksBuildPhaseObj(target:Dynamic):Dynamic;

    function pbxEmbedFrameworksBuildPhaseObj(target:Dynamic):Dynamic;

    function buildPhase(group:String, target:String):String;

    function buildPhaseObject(name:String, group:String, target:String):Dynamic;

    function addBuildProperty(prop:String, value:String, ?buildName:String):Void;

    function removeBuildProperty(prop:String, ?buildName:String):Void;

    function updateBuildProperty(prop:String, value:String, ?buildName:String):Void;

    function updateProductName(name:String):Void;

    function removeFromFrameworkSearchPaths(file:Dynamic):Void;

    function addToFrameworkSearchPaths(file:Dynamic):Void;

    function removeFromLibrarySearchPaths(file:Dynamic):Void;

    function addToLibrarySearchPaths(file:Dynamic):Void;

    function removeFromHeaderSearchPaths(file:Dynamic):Void;

    function addToHeaderSearchPaths(file:Dynamic):Void;

    function addToOtherLinkerFlags(flag:String):Void;

    function removeFromOtherLinkerFlags(flag:String):Void;

    function addToBuildSettings(buildSetting:String, value:String):Void;

    function removeFromBuildSettings(buildSetting:String):Void;

    var productName(default,null):String;

    function hasFile(filePath:String):Bool;

    function addTarget(name:String, type:String, ?subfolder:String):Dynamic;

    function getFirstProject():{uuid:String, firstProject:Dynamic};

    function getFirstTarget():{uuid:String, firstTarget:Dynamic};

    function addToPbxGroup(file:String, groupKey:String):Void;

    function removeFromPbxGroup(file:String, groupKey:String):Void;

    function getPBXGroupByKey(key:String):String;

    function findPBXGroupKey(criteria:{path:String, name:String}):String;

    function pbxCreateGroup(name:String, pathName:String):String;

    function getPBXObject(name:String):Dynamic;

    function addFile(path:String, group:String, ?opt:Dynamic):PbxFile;

    function removeFile(path:String, group:String, ?opt:Dynamic):PbxFile;

    function getBuildProperty(prop:String, ?buildName:String):Dynamic;

    function getBuildConfigByName(name:String):Dynamic;

    function addDataModelDocument(filePath:String, group:String, ?opt:Dynamic):PbxFile;

} //XcodeProject

extern class PbxWriter {

    function write(str:String):Void;

    function writeFlush(str:String):Void;

    function writeSync():String;

    function writeHeadComment():Void;

    function writeProject():Void;

    function writeObject():Void;

    function writeObjectsSections(objects:Dynamic):Void;

    function writeArray(arr:Array<Dynamic>, name:String):Void;

    function writeSectionComment(name:String, ?begin:Bool):Void;

    function writeSection(section:Dynamic):Void;

    function writeInlineObject(n:Dynamic, d:Dynamic, r:Dynamic):Void;

    var contents(default,null):String;

    var sync(default,null):Bool;

    var indentLevel(default,null):Int;

} //PbxWriter

extern class PbxFile {

    var lastKnownFileType:String;

    var group:String;

    var basename:String;

    var sourceTree:String;

    var path:String;

    var settings:Dynamic;

} //PbxFile

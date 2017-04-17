package tools;

import sys.FileSystem;

import js.node.Fs;

class Files {

    public static function haveSameLastModified(filePath1:String, filePath2:String):Bool {

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var time1 = Fs.statSync(filePath1).mtime.getTime();
        var time2 = Fs.statSync(filePath2).mtime.getTime();

        return time1 == time2;

    } //haveSameLastModified

    public static function setToSameLastModified(filePath1:String, filePath2:String):Void {

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (!file1Exists || !file2Exists) return;

        var utime = Math.round(Fs.statSync(filePath1).mtime.getTime() / 1000.0);

        Fs.utimesSync(filePath2, cast utime, cast utime);

    } //haveSameLastModified

    public static function getLastModified(filePath:String):Int {

        if (!FileSystem.exists(filePath)) return -1;

        return Math.round(Fs.statSync(filePath).mtime.getTime() / 1000.0);

    } //getLastModified

} //Files

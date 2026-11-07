package tests;

import ceramic.BrowserFiles;
import ceramic.Files;
import glaze.App;
import glaze.PathPromptOptions;
import glaze.TestDispatcher;
import haxe.io.Bytes;
import testing.TestCase;

/**
 * Deliberate deviation DEV-019 (see DEVIATIONS.md): saving and opening files
 * in a browser. Ceramic's `BrowserFiles` gives downloads and the files picked
 * in the browser's file chooser pseudo paths that `ceramic.Files` reads and
 * writes; the port's path prompts return them on the web
 * (`CeramicPlatformOperations` over `ceramic.Dialogs`). The browser itself
 * (the Blob download, the `<input type="file">` chooser and its user gesture
 * rule) is checked in headless Chromium (`tests/web-files/check.sh`); here the
 * downloads go to `BrowserFiles.downloadHandler` and the browser's dialogs
 * are played by `Dialogs.handler` the way the browser implementation answers.
 */
class BrowserFilesTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final downloads:Array<{name:String, content:String, mimeType:String}> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        BrowserFiles.downloadHandler = (name, bytes, mimeType) -> downloads.push({name: name, content: bytes.toString(), mimeType: mimeType});
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        BrowserFiles.downloadHandler = null;
        #if plugin_dialogs
        ceramic.Dialogs.handler = null;
        #end
        downloads.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function testDownloadPaths() {
        assertEquals('download:export.csv', BrowserFiles.downloadPath('export.csv'));
        assertEquals('download:export.csv', BrowserFiles.downloadPath('/home/me/Downloads/export.csv'));
        assertEquals('download:report.txt', BrowserFiles.downloadPath('C:\\Users\\me\\report.txt'));
        assertEquals('download:download', BrowserFiles.downloadPath(null));
        assertEquals('download:download', BrowserFiles.downloadPath('  '));
        assertEquals('download:ab.csv', BrowserFiles.downloadPath('a?b.csv'));
        assertEquals('export.csv', BrowserFiles.downloadName('download:export.csv'));
        assertTrue(BrowserFiles.isDownloadPath('download:x'));
        assertFalse(BrowserFiles.isBrowserPath('/tmp/download:x'));
        assertEquals('text/csv', BrowserFiles.mimeTypeOf('export.csv'));
        assertEquals('application/octet-stream', BrowserFiles.mimeTypeOf('blob.bin'));
    }

    function testWritingADownloadPathStartsADownload() {
        Files.saveContent('download:export.csv', 'a,b\n1,2\n');
        Files.saveBytes('download:data.bin', Bytes.ofString('xyz'));
        assertEquals(2, downloads.length);
        assertEquals('export.csv', downloads[0].name);
        assertEquals('a,b\n1,2\n', downloads[0].content);
        assertEquals('text/csv', downloads[0].mimeType);
        assertEquals('data.bin', downloads[1].name);
        assertEquals('xyz', downloads[1].content);
        // Nothing can be read back from a download
        assertNull(Files.getContent('download:export.csv'));
        assertFalse(Files.exists('download:export.csv'));
    }

    function testPickedFilesReadLikeFiles() {
        final pick = BrowserFiles.newPick();
        final notes = BrowserFiles.addPicked(pick, 'notes.txt', Bytes.ofString('hello'));
        final inner = BrowserFiles.addPicked(pick, 'folder/sub/data.csv', Bytes.ofString('1,2'));
        final top = BrowserFiles.addPicked(pick, 'folder/top.txt', Bytes.ofString('top'));
        assertEquals(pick + 'notes.txt', notes);
        assertEquals('hello', Files.getContent(notes));
        assertEquals('1,2', Files.getBytes(inner).toString());
        assertEquals(5., Files.getSize(notes));
        assertTrue(Files.exists(notes));
        assertFalse(Files.isDirectory(notes));
        assertTrue(Files.isDirectory(pick + 'folder'));
        assertTrue(Files.isDirectory(pick + 'folder/sub'));
        assertEquals('sub/data.csv,top.txt', Files.getFlatDirectory(pick + 'folder').join(','));
        assertEquals('top.txt', Files.getFlatDirectory(pick + 'folder', true, false, false).join(','));
        assertFalse(Files.exists(pick + 'missing.txt'));
        assertEquals(-1., Files.getSize(pick + 'missing.txt'));

        // A picked file cannot be written
        Files.saveContent(notes, 'changed');
        assertEquals('hello', Files.getContent(notes));
        assertEquals(0, downloads.length);

        BrowserFiles.forget(pick + 'folder');
        assertFalse(Files.exists(inner));
        assertFalse(Files.exists(top));
        assertTrue(Files.exists(notes));
        BrowserFiles.forget(pick);
        assertFalse(Files.exists(notes));

        // Each pick has its own prefix
        assertTrue(BrowserFiles.newPick() != pick);
    }

    #if plugin_dialogs
    /**
     * The data table story's CSV export on the web: the save prompt answers
     * a download path (what `Dialogs.chooseNewPath` gives in a browser) and
     * writing it with `Files` downloads the file.
     */
    function testNewPathPromptThenWriteDownloadsTheFile() {
        ceramic.Dialogs.handler = (save, options, done) -> {
            assertTrue(save);
            done([BrowserFiles.downloadPath(options.defaultName)], null);
        };
        final task = app.promptForNewPath('', 'export.csv');
        ceramic.App.app.flushImmediate();
        assertEquals('download:export.csv', task.value);
        Files.saveContent(task.value, 'Name,Price\nA,1\n');
        assertEquals(1, downloads.length);
        assertEquals('export.csv', downloads[0].name);
        assertEquals('Name,Price\nA,1\n', downloads[0].content);
    }

    /** The open prompt: picked paths, read with `Files`; the gesture error fails the task. */
    function testPathPromptGivesPickedPaths() {
        var answer:Null<(Null<Array<String>>, Null<String>)->Void> = null;
        ceramic.Dialogs.handler = (save, options, done) -> {
            assertFalse(save);
            answer = done;
        };

        final chosen = app.promptForPaths(new PathPromptOptions(true, false, true));
        final pick = BrowserFiles.newPick();
        final a = BrowserFiles.addPicked(pick, 'a.txt', Bytes.ofString('A'));
        final b = BrowserFiles.addPicked(pick, 'b.txt', Bytes.ofString('B'));
        answer([a, b], null);
        ceramic.App.app.flushImmediate();
        assertEquals('A,B', [for (path in chosen.value) Files.getContent(path)].join(','));
        BrowserFiles.forget(pick);

        final outsideGesture = app.promptForPaths(new PathPromptOptions(true, false, false));
        answer(null, 'the browser opens a file chooser only during a user gesture (a click, a tap or a key press)');
        ceramic.App.app.flushImmediate();
        assertTrue(outsideGesture.isFailed);
    }
    #end

}

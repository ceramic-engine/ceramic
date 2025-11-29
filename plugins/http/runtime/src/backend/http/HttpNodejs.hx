package backend.http;

#if (nodejs || hxnodejs || node)

import ceramic.Path;
import ceramic.Shortcuts.*;
import haxe.io.Bytes;
import sys.FileSystem;

using StringTools;

class HttpNodejs {

    public static function request(options:HttpRequestOptions, done:HttpResponse->Void, numRedirects:Int = 0):Void {

        var isSSL = options.url.startsWith('https');
        var http = isSSL ? js.Node.require('https') : js.Node.require('http');
        var url = new js.node.url.URL(options.url);

        var requestOptions:Dynamic = {};
        requestOptions.host = url.hostname;
        requestOptions.port = url.port != null ? url.port : (isSSL ? 443 : 80);
        requestOptions.path = url.pathname;
        requestOptions.method = options.method != null ? options.method : 'GET';

        if (options.timeout != null && options.timeout > 0) {
            requestOptions.timeout = options.timeout * 1000;
        }

        if (options.headers != null) {
            requestOptions.headers = {};
            var i = 0;
            while (i < options.headers.length) {
                var key = options.headers[i];
                var value = options.headers[i + 1];
                Reflect.setField(requestOptions.headers, key, value);
                i += 2;
            }
        }

        var resContent = [];
        var resError = null;
        var resHeaders:Array<String> = [];
        var resStatus = 404;
        var textContent:String = null;
        var binaryContent:Bytes = null;
        var didRedirect:Bool = false;

        var req:Dynamic = http.request(requestOptions, function(res:Dynamic) {

            resStatus = res.statusCode;

            if (numRedirects < 8 && (resStatus >= 300 && resStatus <= 399) && res.headers.location != null) {

                didRedirect = true;

                var newUrl:String = options.url;
                var newLocation:String = res.headers.location;
                if (!newLocation.toLowerCase().startsWith('http://') && !newLocation.toLowerCase().startsWith('https://')) {
                    var slashIndex = newUrl.indexOf('/', 8);
                    if (slashIndex != -1) {
                        newUrl = newUrl.substring(0, slashIndex);
                    }
                    if (newLocation.charAt(0) != '/')
                        newUrl += '/';
                    newUrl += newLocation;
                }
                else {
                    newUrl = newLocation;
                }

                var redirectedOptions:HttpRequestOptions = {
                    url: newUrl
                };
                redirectedOptions.timeout = options.timeout;
                if (resStatus == 307) {
                    redirectedOptions.method = options.method;
                    redirectedOptions.content = options.content;
                    redirectedOptions.headers = options.headers;
                }
                else {
                    redirectedOptions.method = GET;
                    redirectedOptions.content = null;
                }
                request(redirectedOptions, done, numRedirects + 1);
                return;
            }

            res.on('data', function(chunk) {
                if (!didRedirect) {
                    resContent.push(chunk);
                }
            });

            res.on('end', function() {
                if (!didRedirect) {
                    var buffer:Dynamic = js.Syntax.code('Buffer.concat({0})', resContent);

                    var resContentType:String = null;
                    for (key in Reflect.fields(res.headers)) {
                        resHeaders.push(key);
                        resHeaders.push(Reflect.field(res.headers, key));

                        if (resContentType == null && key.toLowerCase() == 'content-type') {
                            resContentType = Reflect.field(res.headers, key);
                        }
                    }

                    if (resContentType == null)
                        resContentType = 'application/octet-stream';

                    if (ceramic.MimeType.isText(resContentType)) {
                        textContent = buffer.toString('utf8');
                    }
                    else {
                        // Copy data and get rid of nodejs buffer
                        var bufferData = new js.lib.Uint8Array(buffer.length);
                        for (i in 0...buffer.length) {
                            bufferData[i] = js.Syntax.code("{0}[{1}]", buffer, i);
                        }
                        binaryContent = haxe.io.Bytes.ofData(bufferData.buffer);
                    }
                }
            });
        });

        req.on('error', function(e) {
            if (!didRedirect) {
                resError = e.message;
            }
        });

        req.on('close', function() {
            if (!didRedirect) {
                done({
                    status: resStatus,
                    content: resStatus < 200 || resStatus >= 300 ? null : textContent,
                    binaryContent: resStatus < 200 || resStatus >= 300 ? null : binaryContent,
                    headers: resHeaders,
                    error: resError
                });
            }
        });

        // Write request body (if any)
        if (options.content != null) {
            req.write(options.content);
        }

        req.end();

    }

    public static function download(url:String, targetPath:String, done:String->Void):Void {

        var tmpTargetPath = targetPath + '.tmpdl';

        // Ensure we can write the file at the desired location
        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.isDirectory(tmpTargetPath)) {
                log.error('Cannot overwrite directory named $tmpTargetPath');
                done(null);
                return;
            }
            FileSystem.deleteFile(tmpTargetPath);
        }
        var dir = Path.directory(tmpTargetPath);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
        else if (!FileSystem.isDirectory(dir)) {
            log.error('Target directory $dir should be a directory, but it is a file');
            done(null);
            return;
        }

        var isSSL = url.startsWith('https');
        var http = isSSL ? js.Node.require('https') : js.Node.require('http');
        var fs = js.Node.require('fs');
        var responded = false;

        var request = http.get(url, function(response:Dynamic) {

            // Check if the request was successful
            if (response.statusCode != 200) {
                log.error('Failed to download $url at path $targetPath. Status code: ${response.statusCode}');
                done(null);
                return;
            }

            // Create a writable stream to save the file
            var fileStream:Dynamic = fs.createWriteStream(tmpTargetPath);
            response.pipe(fileStream);

            fileStream.on('finish', function() {
                fileStream.close();
                if (!responded) {
                    responded = true;
                    finishDownload(tmpTargetPath, targetPath, url, done);
                }
            });

            fileStream.on('error', function(error:Dynamic) {
                if (!responded) {
                    responded = true;
                    log.error('Failed to download $url at path $targetPath. Stream error: $error');
                    done(null);
                    fs.unlink(tmpTargetPath, () -> {});
                }
            });

            response.on('error', function(error:Dynamic) {
                if (!responded) {
                    responded = true;
                    log.error('Failed to download $url at path $targetPath. Response error: $error');
                    done(null);
                    fs.unlink(tmpTargetPath, () -> {});
                }
            });

        });

    }

    static function finishDownload(tmpTargetPath:String, targetPath:String, url:String, done:String->Void):Void {

        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.exists(targetPath)) {
                if (FileSystem.isDirectory(targetPath)) {
                    log.error('Cannot overwrite directory named $targetPath');
                    done(null);
                    return;
                }
                FileSystem.deleteFile(targetPath);
            }
            FileSystem.rename(tmpTargetPath, targetPath);
            if (FileSystem.exists(targetPath) && !FileSystem.isDirectory(targetPath)) {
                log.success('Downloaded file from url $url at path $targetPath');
                done(targetPath);
                return;
            }
            else {
                log.error('Error when copying $tmpTargetPath to $targetPath');
                done(null);
                return;
            }
        }
        else {
            log.error('Failed to download $url at path $targetPath. No downloaded file.');
            done(null);
            return;
        }

    }

}

#end

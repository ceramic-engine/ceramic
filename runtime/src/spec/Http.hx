package spec;

import backend.HttpRequestOptions;
import backend.HttpResponse;

interface Http {

    function request(options:HttpRequestOptions, done:HttpResponse->Void):Void;

} //Http

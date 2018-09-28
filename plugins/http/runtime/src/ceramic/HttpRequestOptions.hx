package ceramic;

/** Augmented and higher level HTTP request options. */
typedef HttpRequestOptions = {

    > backend.HttpRequestOptions,

    @:optional var params:Map<String,String>;

} //HttpRequestOptions


/** Persistent storage */
class Storage {

    get(key:string) {

        var item = localStorage.getItem(key);
        if (item != null) {
            return JSON.parse(item);
        }
        return null;

    } //get

    set(key:string, value:{}) {

        if (value != null) {
            localStorage.setItem(key, JSON.stringify(value));
        }
        else {
            localStorage.removeItem(key);
        }

    } //get

} //Storage

export default new Storage();

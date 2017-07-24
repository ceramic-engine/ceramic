
interface Message {

    type:string;

    value?:any;

} //Message

/** Utility taking advantage of shared Ceramic component to send/receive messages. */
class CeramicProxy {

    component:any;

    send(message:Message, responseHandler?:(message:Message) => void) {

        if (this.component && this.component.ready) {
            this.component.send(message, responseHandler);
        }
        else {
            // If component is not ready, wait
            setTimeout(() => {
                this.send(message, responseHandler);
            }, 100);
        }

    } //send

    /** Listen to the given message type pattern. Returns an unbind function. */
    listen(typePattern:string, listener?:(message:Message) => void):() => void {

        if (this.component && this.component.ready) {
            this.component.listen(typePattern, listener);
        }
        else {
            // If component is not ready, wait
            setTimeout(() => {
                this.listen(typePattern, listener);
            }, 100);
        }

        let removeListener = () => {
            if (this.component && this.component.ready) {
                this.component.removeListener(typePattern, listener);
            }
            else {
                // If component is not ready, wait
                setTimeout(() => {
                    removeListener();
                }, 100);
            }
        };

        return removeListener;

    } //listen

}

export const ceramic = new CeramicProxy();

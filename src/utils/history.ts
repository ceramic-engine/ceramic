import autobind from 'autobind-decorator';
import { EventEmitter } from 'events';

export interface HistoryItem {

    do:any;

    undo:any;

}

export interface HistoryListener {

    onHistoryUndo(item:HistoryItem):void;

    onHistoryRedo(item:HistoryItem):void;

}

@autobind export class History extends EventEmitter {

    doing:boolean = false;

    items:Array<HistoryItem> = [];

    index:number = -1;

    pauses:number = 0;

    started:boolean = false;

    listener:HistoryListener = {

        onHistoryUndo(item:HistoryItem) {
            // Default listener, doing nothing
        },

        onHistoryRedo(item:HistoryItem) {
            // Default listener, doing nothing
        }

    };

    /** Add a new history item
        @return `true` if the item was added, `false` if forbidden because already `doing`. */
    push(item:HistoryItem) {

        if (!this.started) return false;

        // Record item only if not undoing/redoing
        if (!this.doing && this.pauses === 0) {
            this.items[++this.index] = item;
            if (this.items.length > this.index + 1) {
                this.items.length = this.index + 1;
            }

            this.emit('push');

            return true;
        }

        return false;

    } //push

    /** Undo the previous item in history (if any)
        @return `true` if there was an item to undo. */
    undo():boolean;
    /** Request the previous item in history to undo it in callback (if any)
        @return `true` if there was an item to undo. */
    undo(callback:(item:HistoryItem) => void):boolean;

    undo(callback?:(item:HistoryItem) => void):boolean {

        if (!this.started) return false;

        // Ensure the callback is not some kind of event (React), if given
        if (callback != null && !callback.constructor.name.endsWith('Event')) {

            var canUndo = false;

            var wasDoing = this.doing;
            if (!wasDoing) {
                this.doing = true;
            }

            if (this.index >= 0) {
                var item = this.items[this.index--];
                if (item) {
                    canUndo = true;
                    callback(item);
                } else {
                    console.warn('Unexpected missing item when undoing.');
                }
            }
            
            if (!wasDoing) {
                this.doing = false;
            }

            return canUndo;
        }
        else {
            return this.undo(this.listener.onHistoryUndo);
        }

    } //undo

    /** Redo the next item in history (if any)
        @return `true` if there was an item to redo. */
    redo():boolean;
    /** Request the next item in history to redo it in callback (if any)
        @return `true` if there was an item to redo. */
    redo(callback:(item:HistoryItem) => void):boolean;

    redo(callback?:(item:HistoryItem) => void):boolean {

        if (!this.started) return false;

        if (callback != null && !callback.constructor.name.endsWith('Event')) {
            var canRedo = false;

            var wasDoing = this.doing;
            if (!wasDoing) {
                this.doing = true;
            }

            if (this.items.length > this.index + 1) {
                var item = this.items[++this.index];
                if (item) {
                    canRedo = true;
                    callback(item);
                } else {
                    console.warn('Unexpected missing item when redoing.');
                }
            }
            
            if (!wasDoing) {
                this.doing = false;
            }

            return canRedo;
        }
        else {
            return this.redo(this.listener.onHistoryRedo);
        }

    } //redo

    clear():void {

        this.items = [];
        this.index = -1;

    } //clear

    start():void {

        if (this.started) return;
        this.started = true;

    } //start

    pause():void {

        this.pauses++;

    } //pause

    resume():void {

        this.pauses--;

    } //resume

}

export const history = new History();

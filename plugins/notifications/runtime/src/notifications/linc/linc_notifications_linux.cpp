// System notifications on Linux: the org.freedesktop.Notifications service
// (Desktop Notifications Specification 1.2) over the session DBus.
//
// libdbus is loaded at run time (dlopen of libdbus-1.so.3): the app has no
// build or link dependency on it, and notifications are unavailable where it
// is missing or no session bus or notification service is reachable. The
// few types and functions used are declared here instead of including the
// libdbus headers.
//
// Everything runs on the main thread: Notify is sent with a pending reply
// (the id the service assigns), and poll() (once per frame) reads and
// dispatches what arrived: the replies, and the ActionInvoked and
// NotificationClosed signals through a filter. Like GPUI's Linux platform
// (gpui-pre-linux 0.3.10, src/linux/system_notifications.rs), the body is
// the "default" action and the buttons get transport keys
// ("ceramic-action-<n>") mapped back to their ids, so an application action
// named "default" cannot be mistaken for the body. Unlike it, a notification
// shown again with the same tag replaces the previous one (replaces_id) and
// dismiss closes it (CloseNotification): the ids the service assigns are
// kept per tag.

#include "linc_notifications.h"

#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <map>
#include <string>
#include <vector>

namespace {

    // libdbus declarations (dbus/dbus.h)

    typedef uint32_t dbus_bool_t;
    typedef uint32_t dbus_uint32_t;
    typedef int32_t dbus_int32_t;

    struct DBusConnection;
    struct DBusMessage;
    struct DBusPendingCall;

    struct DBusError {
        const char *name;
        const char *message;
        unsigned int dummy1 : 1;
        unsigned int dummy2 : 1;
        unsigned int dummy3 : 1;
        unsigned int dummy4 : 1;
        unsigned int dummy5 : 1;
        void *padding1;
    };

    // Larger than libdbus's DBusMessageIter (14 words on 64 bit targets):
    // only libdbus writes in it
    struct DBusMessageIter {
        void *storage[24];
    };

    enum {
        DBUS_BUS_SESSION = 0
    };

    enum {
        DBUS_HANDLER_RESULT_HANDLED = 0,
        DBUS_HANDLER_RESULT_NOT_YET_HANDLED = 1
    };

    enum {
        DBUS_DISPATCH_DATA_REMAINS = 0
    };

    enum {
        DBUS_MESSAGE_TYPE_METHOD_RETURN = 2,
        DBUS_MESSAGE_TYPE_ERROR = 3,
        DBUS_MESSAGE_TYPE_SIGNAL = 4
    };

    const int DBUS_TYPE_INVALID = 0;
    const int DBUS_TYPE_STRING = 's';
    const int DBUS_TYPE_UINT32 = 'u';
    const int DBUS_TYPE_INT32 = 'i';
    const int DBUS_TYPE_ARRAY = 'a';
    const int DBUS_TYPE_VARIANT = 'v';
    const int DBUS_TYPE_DICT_ENTRY = 'e';

    typedef int (*DBusHandleMessageFunction)(DBusConnection *connection, DBusMessage *message, void *data);
    typedef void (*DBusPendingCallNotifyFunction)(DBusPendingCall *pending, void *data);
    typedef void (*DBusFreeFunction)(void *memory);

    struct DBusApi {
        void (*error_init)(DBusError *error);
        dbus_bool_t (*error_is_set)(const DBusError *error);
        void (*error_free)(DBusError *error);
        DBusConnection *(*bus_get)(int type, DBusError *error);
        void (*connection_set_exit_on_disconnect)(DBusConnection *connection, dbus_bool_t exit);
        dbus_bool_t (*bus_start_service_by_name)(DBusConnection *connection, const char *name, dbus_uint32_t flags, dbus_uint32_t *result, DBusError *error);
        void (*bus_add_match)(DBusConnection *connection, const char *rule, DBusError *error);
        dbus_bool_t (*connection_add_filter)(DBusConnection *connection, DBusHandleMessageFunction function, void *data, DBusFreeFunction free);
        DBusMessage *(*message_new_method_call)(const char *destination, const char *path, const char *iface, const char *method);
        void (*message_iter_init_append)(DBusMessage *message, DBusMessageIter *iter);
        dbus_bool_t (*message_iter_append_basic)(DBusMessageIter *iter, int type, const void *value);
        dbus_bool_t (*message_iter_open_container)(DBusMessageIter *iter, int type, const char *signature, DBusMessageIter *sub);
        dbus_bool_t (*message_iter_close_container)(DBusMessageIter *iter, DBusMessageIter *sub);
        dbus_bool_t (*connection_send)(DBusConnection *connection, DBusMessage *message, dbus_uint32_t *serial);
        dbus_bool_t (*connection_send_with_reply)(DBusConnection *connection, DBusMessage *message, DBusPendingCall **pending, int timeout);
        dbus_bool_t (*pending_call_set_notify)(DBusPendingCall *pending, DBusPendingCallNotifyFunction function, void *data, DBusFreeFunction free);
        DBusMessage *(*pending_call_steal_reply)(DBusPendingCall *pending);
        void (*pending_call_unref)(DBusPendingCall *pending);
        void (*message_unref)(DBusMessage *message);
        int (*message_get_type)(DBusMessage *message);
        dbus_bool_t (*message_is_signal)(DBusMessage *message, const char *iface, const char *name);
        dbus_bool_t (*message_iter_init)(DBusMessage *message, DBusMessageIter *iter);
        int (*message_iter_get_arg_type)(DBusMessageIter *iter);
        void (*message_iter_get_basic)(DBusMessageIter *iter, void *value);
        dbus_bool_t (*message_iter_next)(DBusMessageIter *iter);
        dbus_bool_t (*connection_read_write)(DBusConnection *connection, int timeout);
        int (*connection_dispatch)(DBusConnection *connection);
        void (*connection_flush)(DBusConnection *connection);
    };

    const char *SERVICE = "org.freedesktop.Notifications";
    const char *PATH = "/org/freedesktop/Notifications";
    const char *INTERFACE = "org.freedesktop.Notifications";
    const char *DEFAULT_ACTION = "default";
    const char *ACTION_PREFIX = "ceramic-action-";

    DBusApi api;
    void *library = NULL;
    bool libraryLoaded = false;
    bool libraryFailed = false;

    bool started = false;
    DBusConnection *connection = NULL;

    std::string appIdentifier;
    std::string appName;

    // A notification shown for a tag
    struct TagState {
        dbus_uint32_t id = 0;       // assigned by the service, 0 until the reply
        unsigned int request = 0;   // the latest Notify request of this tag
        bool dismissed = false;     // dismissed while the reply was pending
        std::vector<std::string> actionIds;
    };

    std::map<std::string, TagState> tags;
    std::map<dbus_uint32_t, std::string> tagsById;
    unsigned int nextRequest = 1;

    struct PendingNotify {
        std::string tag;
        unsigned int request;
    };

    template <typename T>
    bool loadSymbol(T &target, const char *name) {
        target = (T)dlsym(library, name);
        if (target == NULL) {
            fprintf(stderr, "System notifications disabled: %s missing in libdbus\n", name);
            return false;
        }
        return true;
    }

    bool loadLibrary() {
        if (libraryLoaded) return true;
        if (libraryFailed) return false;
        library = dlopen("libdbus-1.so.3", RTLD_NOW | RTLD_LOCAL);
        if (library == NULL) library = dlopen("libdbus-1.so", RTLD_NOW | RTLD_LOCAL);
        if (library == NULL) {
            libraryFailed = true;
            return false;
        }
        bool ok = true;
        ok = loadSymbol(api.error_init, "dbus_error_init") && ok;
        ok = loadSymbol(api.error_is_set, "dbus_error_is_set") && ok;
        ok = loadSymbol(api.error_free, "dbus_error_free") && ok;
        ok = loadSymbol(api.bus_get, "dbus_bus_get") && ok;
        ok = loadSymbol(api.connection_set_exit_on_disconnect, "dbus_connection_set_exit_on_disconnect") && ok;
        ok = loadSymbol(api.bus_start_service_by_name, "dbus_bus_start_service_by_name") && ok;
        ok = loadSymbol(api.bus_add_match, "dbus_bus_add_match") && ok;
        ok = loadSymbol(api.connection_add_filter, "dbus_connection_add_filter") && ok;
        ok = loadSymbol(api.message_new_method_call, "dbus_message_new_method_call") && ok;
        ok = loadSymbol(api.message_iter_init_append, "dbus_message_iter_init_append") && ok;
        ok = loadSymbol(api.message_iter_append_basic, "dbus_message_iter_append_basic") && ok;
        ok = loadSymbol(api.message_iter_open_container, "dbus_message_iter_open_container") && ok;
        ok = loadSymbol(api.message_iter_close_container, "dbus_message_iter_close_container") && ok;
        ok = loadSymbol(api.connection_send, "dbus_connection_send") && ok;
        ok = loadSymbol(api.connection_send_with_reply, "dbus_connection_send_with_reply") && ok;
        ok = loadSymbol(api.pending_call_set_notify, "dbus_pending_call_set_notify") && ok;
        ok = loadSymbol(api.pending_call_steal_reply, "dbus_pending_call_steal_reply") && ok;
        ok = loadSymbol(api.pending_call_unref, "dbus_pending_call_unref") && ok;
        ok = loadSymbol(api.message_unref, "dbus_message_unref") && ok;
        ok = loadSymbol(api.message_get_type, "dbus_message_get_type") && ok;
        ok = loadSymbol(api.message_is_signal, "dbus_message_is_signal") && ok;
        ok = loadSymbol(api.message_iter_init, "dbus_message_iter_init") && ok;
        ok = loadSymbol(api.message_iter_get_arg_type, "dbus_message_iter_get_arg_type") && ok;
        ok = loadSymbol(api.message_iter_get_basic, "dbus_message_iter_get_basic") && ok;
        ok = loadSymbol(api.message_iter_next, "dbus_message_iter_next") && ok;
        ok = loadSymbol(api.connection_read_write, "dbus_connection_read_write") && ok;
        ok = loadSymbol(api.connection_dispatch, "dbus_connection_dispatch") && ok;
        ok = loadSymbol(api.connection_flush, "dbus_connection_flush") && ok;
        if (!ok) {
            dlclose(library);
            library = NULL;
            libraryFailed = true;
            return false;
        }
        libraryLoaded = true;
        return true;
    }

    void appendString(DBusMessageIter *iter, const std::string &value) {
        const char *chars = value.c_str();
        api.message_iter_append_basic(iter, DBUS_TYPE_STRING, &chars);
    }

    void appendUint32(DBusMessageIter *iter, dbus_uint32_t value) {
        api.message_iter_append_basic(iter, DBUS_TYPE_UINT32, &value);
    }

    void appendInt32(DBusMessageIter *iter, dbus_int32_t value) {
        api.message_iter_append_basic(iter, DBUS_TYPE_INT32, &value);
    }

    void closeNotification(dbus_uint32_t id) {
        if (connection == NULL || id == 0) return;
        DBusMessage *message = api.message_new_method_call(SERVICE, PATH, INTERFACE, "CloseNotification");
        if (message == NULL) return;
        DBusMessageIter args;
        api.message_iter_init_append(message, &args);
        appendUint32(&args, id);
        api.connection_send(connection, message, NULL);
        api.message_unref(message);
        api.connection_flush(connection);
    }

    void forgetId(dbus_uint32_t id) {
        std::map<dbus_uint32_t, std::string>::iterator byId = tagsById.find(id);
        if (byId == tagsById.end()) return;
        std::map<std::string, TagState>::iterator byTag = tags.find(byId->second);
        if (byTag != tags.end() && byTag->second.id == id) tags.erase(byTag);
        tagsById.erase(byId);
    }

    // Reply to Notify: the id the service assigned
    void handleNotifyReply(DBusPendingCall *pending, void *data) {
        PendingNotify *notify = (PendingNotify *)data;
        DBusMessage *reply = api.pending_call_steal_reply(pending);
        dbus_uint32_t id = 0;
        if (reply != NULL) {
            if (api.message_get_type(reply) == DBUS_MESSAGE_TYPE_METHOD_RETURN) {
                DBusMessageIter iter;
                if (api.message_iter_init(reply, &iter) && api.message_iter_get_arg_type(&iter) == DBUS_TYPE_UINT32) {
                    api.message_iter_get_basic(&iter, &id);
                }
            }
            else {
                fprintf(stderr, "Failed to show system notification (DBus error reply)\n");
            }
            api.message_unref(reply);
        }
        api.pending_call_unref(pending);
        if (id == 0) return;

        std::map<std::string, TagState>::iterator byTag = tags.find(notify->tag);
        bool current = byTag != tags.end() && byTag->second.request == notify->request;
        if (!current) {
            // Shown again before this reply came: this one was superseded
            bool kept = byTag != tags.end() && byTag->second.id == id;
            if (!kept) closeNotification(id);
            return;
        }
        TagState &state = byTag->second;
        if (state.id != 0 && state.id != id) tagsById.erase(state.id);
        state.id = id;
        tagsById[id] = notify->tag;
        if (state.dismissed) {
            closeNotification(id);
            tagsById.erase(id);
            tags.erase(byTag);
        }
    }

    void freePendingNotify(void *data) {
        delete (PendingNotify *)data;
    }

    // ActionInvoked(u id, s action_key) and NotificationClosed(u id, u reason)
    int handleSignal(DBusConnection *, DBusMessage *message, void *) {
        if (api.message_get_type(message) != DBUS_MESSAGE_TYPE_SIGNAL) return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

        if (api.message_is_signal(message, INTERFACE, "ActionInvoked")) {
            DBusMessageIter iter;
            dbus_uint32_t id = 0;
            const char *key = NULL;
            if (!api.message_iter_init(message, &iter) || api.message_iter_get_arg_type(&iter) != DBUS_TYPE_UINT32) return DBUS_HANDLER_RESULT_HANDLED;
            api.message_iter_get_basic(&iter, &id);
            if (!api.message_iter_next(&iter) || api.message_iter_get_arg_type(&iter) != DBUS_TYPE_STRING) return DBUS_HANDLER_RESULT_HANDLED;
            api.message_iter_get_basic(&iter, &key);

            // Signals of other applications' notifications are ignored
            std::map<dbus_uint32_t, std::string>::iterator byId = tagsById.find(id);
            if (byId == tagsById.end() || key == NULL) return DBUS_HANDLER_RESULT_HANDLED;
            std::map<std::string, TagState>::iterator byTag = tags.find(byId->second);
            if (byTag == tags.end()) return DBUS_HANDLER_RESULT_HANDLED;

            std::string action(key);
            if (action == DEFAULT_ACTION) {
                linc::notifications::pushResponse(byTag->first, NULL);
            }
            else if (action.compare(0, strlen(ACTION_PREFIX), ACTION_PREFIX) == 0) {
                int index = atoi(action.c_str() + strlen(ACTION_PREFIX));
                if (index >= 0 && index < (int)byTag->second.actionIds.size()) {
                    linc::notifications::pushResponse(byTag->first, &byTag->second.actionIds[index]);
                }
            }
            return DBUS_HANDLER_RESULT_HANDLED;
        }

        if (api.message_is_signal(message, INTERFACE, "NotificationClosed")) {
            DBusMessageIter iter;
            dbus_uint32_t id = 0;
            if (api.message_iter_init(message, &iter) && api.message_iter_get_arg_type(&iter) == DBUS_TYPE_UINT32) {
                api.message_iter_get_basic(&iter, &id);
                // ActionInvoked comes before NotificationClosed: the response is queued already
                forgetId(id);
            }
            return DBUS_HANDLER_RESULT_HANDLED;
        }

        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
    }

    void dispatchPending() {
        if (connection == NULL) return;
        api.connection_read_write(connection, 0);
        while (api.connection_dispatch(connection) == DBUS_DISPATCH_DATA_REMAINS) {}
    }

}

namespace linc {
    namespace notifications {

        bool available() {
            return loadLibrary();
        }

        void setAppIdentity(::String identifier, ::String name) {
            appIdentifier = toStdString(identifier);
            appName = toStdString(name);
        }

        bool start() {
            if (started) return connection != NULL;
            started = true;
            if (!loadLibrary()) return false;

            DBusError error;
            api.error_init(&error);
            connection = api.bus_get(DBUS_BUS_SESSION, &error);
            if (api.error_is_set(&error) || connection == NULL) {
                fprintf(stderr, "System notifications disabled: no session bus (%s)\n", error.message != NULL ? error.message : "");
                api.error_free(&error);
                connection = NULL;
                return false;
            }
            api.connection_set_exit_on_disconnect(connection, 0);

            // Starts the notification service when it is activatable and not running yet
            dbus_uint32_t result = 0;
            if (!api.bus_start_service_by_name(connection, SERVICE, 0, &result, &error)) {
                fprintf(stderr, "System notifications disabled: no notification service (%s)\n", error.message != NULL ? error.message : "");
                api.error_free(&error);
                connection = NULL;
                return false;
            }

            api.bus_add_match(connection, "type='signal',interface='org.freedesktop.Notifications',member='ActionInvoked'", &error);
            if (api.error_is_set(&error)) api.error_free(&error);
            api.bus_add_match(connection, "type='signal',interface='org.freedesktop.Notifications',member='NotificationClosed'", &error);
            if (api.error_is_set(&error)) api.error_free(&error);
            api.connection_add_filter(connection, handleSignal, NULL, NULL);
            return true;
        }

        void readAuthorization() {
            // The service never asks the user
            pushAuthorization(start() ? AUTHORIZATION_AUTHORIZED : AUTHORIZATION_UNAVAILABLE, false);
        }

        void requestAuthorization() {
            pushAuthorization(start() ? AUTHORIZATION_AUTHORIZED : AUTHORIZATION_UNAVAILABLE, true);
        }

        void show(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
            if (!start()) return;

            std::string tagValue = toStdString(tag);
            TagState &state = tags[tagValue];
            state.request = nextRequest++;
            state.dismissed = false;
            state.actionIds.clear();

            DBusMessage *message = api.message_new_method_call(SERVICE, PATH, INTERFACE, "Notify");
            if (message == NULL) return;
            DBusMessageIter args;
            api.message_iter_init_append(message, &args);

            appendString(&args, appName);
            // The same tag replaces the notification shown before (when its id is known)
            appendUint32(&args, state.id);
            appendString(&args, std::string());
            appendString(&args, toStdString(title));
            appendString(&args, toStdString(body));

            DBusMessageIter actions;
            api.message_iter_open_container(&args, DBUS_TYPE_ARRAY, "s", &actions);
            appendString(&actions, DEFAULT_ACTION);
            appendString(&actions, DEFAULT_ACTION);
            int count = actionIds != null() ? actionIds->length : 0;
            for (int i = 0; i < count; i++) {
                char key[48];
                snprintf(key, sizeof(key), "%s%d", ACTION_PREFIX, i);
                appendString(&actions, key);
                appendString(&actions, actionLabels != null() && i < actionLabels->length ? toStdString(actionLabels[i]) : std::string());
                state.actionIds.push_back(toStdString(actionIds[i]));
            }
            api.message_iter_close_container(&args, &actions);

            DBusMessageIter hints;
            api.message_iter_open_container(&args, DBUS_TYPE_ARRAY, "{sv}", &hints);
            if (!appIdentifier.empty()) {
                DBusMessageIter entry;
                DBusMessageIter variant;
                api.message_iter_open_container(&hints, DBUS_TYPE_DICT_ENTRY, NULL, &entry);
                appendString(&entry, "desktop-entry");
                api.message_iter_open_container(&entry, DBUS_TYPE_VARIANT, "s", &variant);
                appendString(&variant, appIdentifier);
                api.message_iter_close_container(&entry, &variant);
                api.message_iter_close_container(&hints, &entry);
            }
            api.message_iter_close_container(&args, &hints);

            // The service's default timeout
            appendInt32(&args, -1);

            DBusPendingCall *pending = NULL;
            if (api.connection_send_with_reply(connection, message, &pending, -1) && pending != NULL) {
                PendingNotify *notify = new PendingNotify();
                notify->tag = tagValue;
                notify->request = state.request;
                api.pending_call_set_notify(pending, handleNotifyReply, notify, freePendingNotify);
            }
            api.message_unref(message);
            api.connection_flush(connection);
        }

        void dismiss(::String tag) {
            if (!start()) return;
            std::map<std::string, TagState>::iterator byTag = tags.find(toStdString(tag));
            if (byTag == tags.end()) return;
            if (byTag->second.id == 0) {
                // Closed once the service tells its id
                byTag->second.dismissed = true;
                return;
            }
            closeNotification(byTag->second.id);
            tagsById.erase(byTag->second.id);
            tags.erase(byTag);
        }

        void poll() {
            dispatchPending();
        }

        ::String describe() {
            char out[256];
            snprintf(out, sizeof(out), "libdbus=%d started=%d connection=%d tags=%d ids=%d",
                libraryLoaded ? 1 : 0, started ? 1 : 0, connection != NULL ? 1 : 0, (int)tags.size(), (int)tagsById.size());
            return ::String::create(out);
        }

        ::String describeRequest(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
            std::string out = "app=" + appName + " replaces=";
            std::map<std::string, TagState>::iterator byTag = tags.find(toStdString(tag));
            char id[16];
            snprintf(id, sizeof(id), "%u", byTag != tags.end() ? byTag->second.id : 0);
            out += id;
            out += " summary=" + toStdString(title) + " body=" + toStdString(body) + " actions=default:default";
            int count = actionIds != null() ? actionIds->length : 0;
            for (int i = 0; i < count; i++) {
                char key[48];
                snprintf(key, sizeof(key), ",%s%d:", ACTION_PREFIX, i);
                out += key;
                out += actionLabels != null() && i < actionLabels->length ? toStdString(actionLabels[i]) : std::string();
            }
            if (!appIdentifier.empty()) out += " desktop-entry=" + appIdentifier;
            return fromStdString(out);
        }

        ::String describeCategories(int timeoutMs) {
            return ::String::create("");
        }

        int readAuthorizationNow(int timeoutMs) {
            return start() ? AUTHORIZATION_AUTHORIZED : AUTHORIZATION_UNAVAILABLE;
        }

    }
}

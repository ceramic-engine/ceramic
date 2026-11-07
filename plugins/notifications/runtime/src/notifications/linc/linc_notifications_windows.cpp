// System notifications on Windows: toast notifications through WinRT
// (Windows.UI.Notifications), written with C++/WinRT (the cppwinrt headers of
// the Windows 10 SDK, C++17).
//
// UNTESTED: written without a Windows machine. It follows GPUI's Windows
// platform (gpui-pre-windows 0.3.10, src/system_notifications.rs and
// platform.rs set_app_identity):
//
// - setAppIdentity sets the process AppUserModelID
//   (SetCurrentProcessExplicitAppUserModelID) and keeps the identity. An
//   unpackaged app has no identity of its own: posts are dropped with a
//   warning until setAppIdentity was called (GPUI does the same).
// - The first post registers the AppUserModelID for the current user
//   (HKCU\Software\Classes\AppUserModelId\<id>, DisplayName = the name),
//   which lets Windows show toasts of an unpackaged app without a Start menu
//   shortcut, then creates the notifier with that id.
// - A toast is ToastGeneric with the title and body texts, one action per
//   button (arguments = the action id), silent audio. Its tag is a hash of
//   the notification tag (Windows limits tags to 64 characters); a toast
//   shown again with the same tag hides the previous one first.
// - The Activated event of the toast (another thread) queues the response:
//   empty arguments is the body (null action id), otherwise the button's id.
//   Like GPUI, only toasts posted by the running process answer: there is
//   no COM activator, so a click after the app quit does nothing.
// - dismiss hides the toast posted for the tag.
//
// The test procedure for the owner is in docs/CERAMIC_APIS.md of glaze-golden.

#include "linc_notifications.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <shobjidl.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.UI.Notifications.h>

#include <stdio.h>
#include <wchar.h>

#include <map>
#include <string>

// Qualified names: hxcpp declares global types (String, Array, null) and the
// ABI headers a global IInspectable
using winrt::hresult_error;
using winrt::hstring;
using winrt::Windows::Data::Xml::Dom::XmlDocument;
using winrt::Windows::Data::Xml::Dom::XmlElement;
using winrt::Windows::UI::Notifications::NotificationSetting;
using winrt::Windows::UI::Notifications::ToastActivatedEventArgs;
using winrt::Windows::UI::Notifications::ToastNotification;
using winrt::Windows::UI::Notifications::ToastNotificationManager;
using winrt::Windows::UI::Notifications::ToastNotifier;

namespace {

    bool hasIdentity = false;
    std::wstring appIdentifier;
    std::wstring appName;

    bool apartmentReady = false;
    bool notifierFailed = false;
    ToastNotifier notifier { nullptr };

    // The toast shown for each tag
    std::map<std::string, ToastNotification> toasts;

    std::wstring wide(const std::string &value) {
        if (value.empty()) return std::wstring();
        int length = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), (int)value.size(), NULL, 0);
        std::wstring result(length, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, value.c_str(), (int)value.size(), &result[0], length);
        return result;
    }

    std::string narrow(const std::wstring &value) {
        if (value.empty()) return std::string();
        int length = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), (int)value.size(), NULL, 0, NULL, NULL);
        std::string result(length, '\0');
        WideCharToMultiByte(CP_UTF8, 0, value.c_str(), (int)value.size(), &result[0], length, NULL, NULL);
        return result;
    }

    // Windows caps toast tags at 64 characters: a fixed width hash (FNV-1a)
    std::wstring toastTag(const std::string &tag) {
        unsigned long long hash = 1469598103934665603ULL;
        for (size_t i = 0; i < tag.size(); i++) {
            hash ^= (unsigned char)tag[i];
            hash *= 1099511628211ULL;
        }
        wchar_t out[17];
        swprintf(out, 17, L"%016llx", hash);
        return std::wstring(out);
    }

    void ensureApartment() {
        if (apartmentReady) return;
        apartmentReady = true;
        try {
            // SDL's thread may be initialized already (COM): any apartment works
            winrt::init_apartment(winrt::apartment_type::single_threaded);
        }
        catch (const hresult_error &) {
        }
    }

    // Lets an unpackaged app show toasts without a Start menu shortcut
    void registerAppUserModelId() {
        std::wstring keyPath = L"Software\\Classes\\AppUserModelId\\" + appIdentifier;
        HKEY key = NULL;
        if (RegCreateKeyExW(HKEY_CURRENT_USER, keyPath.c_str(), 0, NULL, 0, KEY_SET_VALUE, NULL, &key, NULL) != ERROR_SUCCESS) {
            fprintf(stderr, "Failed to register the AppUserModelID: notifications may not display\n");
            return;
        }
        RegSetValueExW(key, L"DisplayName", 0, REG_SZ, (const BYTE *)appName.c_str(), (DWORD)((appName.size() + 1) * sizeof(wchar_t)));
        RegCloseKey(key);
    }

    bool ensureNotifier() {
        if (notifier) return true;
        if (notifierFailed) return false;
        if (!hasIdentity) {
            fprintf(stderr, "Cannot show a system notification without an app identity: call Notifications.setAppIdentity during startup\n");
            return false;
        }
        ensureApartment();
        try {
            registerAppUserModelId();
            notifier = ToastNotificationManager::CreateToastNotifier(hstring(appIdentifier));
            return true;
        }
        catch (const hresult_error &error) {
            notifierFailed = true;
            fprintf(stderr, "System notifications disabled: %s\n", narrow(std::wstring(error.message())).c_str());
            return false;
        }
    }

    XmlDocument toastDocument(const std::wstring &title, const std::wstring &body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
        XmlDocument document;
        XmlElement toast = document.CreateElement(L"toast");
        document.AppendChild(toast);

        XmlElement visual = document.CreateElement(L"visual");
        toast.AppendChild(visual);
        XmlElement binding = document.CreateElement(L"binding");
        binding.SetAttribute(L"template", L"ToastGeneric");
        visual.AppendChild(binding);
        const std::wstring *texts[2] = { &title, &body };
        for (int i = 0; i < 2; i++) {
            XmlElement text = document.CreateElement(L"text");
            text.InnerText(hstring(*texts[i]));
            binding.AppendChild(text);
        }

        int count = actionIds != null() ? actionIds->length : 0;
        if (count > 0) {
            XmlElement actions = document.CreateElement(L"actions");
            toast.AppendChild(actions);
            for (int i = 0; i < count; i++) {
                XmlElement action = document.CreateElement(L"action");
                std::wstring label = actionLabels != null() && i < actionLabels->length ? wide(linc::notifications::toStdString(actionLabels[i])) : std::wstring();
                action.SetAttribute(L"content", hstring(label));
                action.SetAttribute(L"arguments", hstring(wide(linc::notifications::toStdString(actionIds[i]))));
                actions.AppendChild(action);
            }
        }

        XmlElement audio = document.CreateElement(L"audio");
        audio.SetAttribute(L"silent", L"true");
        toast.AppendChild(audio);
        return document;
    }

}

namespace linc {
    namespace notifications {

        bool available() {
            // Toasts need Windows 10 or later; the identity is checked when posting
            return true;
        }

        void setAppIdentity(::String identifier, ::String name) {
            appIdentifier = wide(toStdString(identifier));
            appName = wide(toStdString(name));
            hasIdentity = !appIdentifier.empty();
            if (hasIdentity) {
                HRESULT result = SetCurrentProcessExplicitAppUserModelID(appIdentifier.c_str());
                if (FAILED(result)) {
                    fprintf(stderr, "Failed to set the process AppUserModelID\n");
                }
            }
        }

        bool start() {
            ensureApartment();
            return true;
        }

        static int currentAuthorization() {
            if (!ensureNotifier()) return hasIdentity ? AUTHORIZATION_UNAVAILABLE : AUTHORIZATION_NOT_DETERMINED;
            try {
                // The user can turn the app's notifications off in the system settings
                return notifier.Setting() == NotificationSetting::Enabled ? AUTHORIZATION_AUTHORIZED : AUTHORIZATION_DENIED;
            }
            catch (const hresult_error &) {
                return AUTHORIZATION_AUTHORIZED;
            }
        }

        void readAuthorization() {
            pushAuthorization(currentAuthorization(), false);
        }

        void requestAuthorization() {
            // Windows never asks the user
            pushAuthorization(currentAuthorization(), true);
        }

        void show(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
            if (!ensureNotifier()) return;
            std::string tagValue = toStdString(tag);
            try {
                XmlDocument document = toastDocument(wide(toStdString(title)), wide(toStdString(body)), actionIds, actionLabels);
                ToastNotification toast(document);
                toast.Tag(hstring(toastTag(tagValue)));

                toast.Activated([tagValue](ToastNotification const &, winrt::Windows::Foundation::IInspectable const &arguments) {
                    std::string actionId;
                    ToastActivatedEventArgs activated = arguments.try_as<ToastActivatedEventArgs>();
                    if (activated) actionId = narrow(std::wstring(activated.Arguments()));
                    // Called on another thread: the queue is thread safe
                    pushResponse(tagValue, actionId.empty() ? NULL : &actionId);
                });

                std::map<std::string, ToastNotification>::iterator previous = toasts.find(tagValue);
                if (previous != toasts.end()) {
                    notifier.Hide(previous->second);
                    toasts.erase(previous);
                }
                notifier.Show(toast);
                toasts.insert(std::make_pair(tagValue, toast));
            }
            catch (const hresult_error &error) {
                fprintf(stderr, "Failed to show system notification: %s\n", narrow(std::wstring(error.message())).c_str());
            }
        }

        void dismiss(::String tag) {
            std::map<std::string, ToastNotification>::iterator found = toasts.find(toStdString(tag));
            if (found == toasts.end() || !notifier) return;
            try {
                notifier.Hide(found->second);
            }
            catch (const hresult_error &error) {
                fprintf(stderr, "Failed to dismiss system notification: %s\n", narrow(std::wstring(error.message())).c_str());
            }
            toasts.erase(found);
        }

        void poll() {
            // Responses arrive through the Activated events (event queue)
        }

        ::String describe() {
            char out[256];
            snprintf(out, sizeof(out), "identity=%d notifier=%d toasts=%d", hasIdentity ? 1 : 0, notifier ? 1 : 0, (int)toasts.size());
            return ::String::create(out);
        }

        ::String describeRequest(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
            // The toast XML show() would post, not posted
            try {
                ensureApartment();
                XmlDocument document = toastDocument(wide(toStdString(title)), wide(toStdString(body)), actionIds, actionLabels);
                std::string out = "tag=" + narrow(toastTag(toStdString(tag))) + " xml=" + narrow(std::wstring(document.GetXml()));
                return fromStdString(out);
            }
            catch (const hresult_error &error) {
                return fromStdString("error " + narrow(std::wstring(error.message())));
            }
        }

        ::String describeCategories(int timeoutMs) {
            return ::String::create("");
        }

        int readAuthorizationNow(int timeoutMs) {
            return currentAuthorization();
        }

    }
}

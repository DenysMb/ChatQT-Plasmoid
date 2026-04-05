/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "components"
import "logic/ApiClient.js" as ApiClient

PlasmoidItem {
    id: root

    property string parentMessageId: ''
    property string currentModel: ''
    property var listModelController;
    property var scrollViewRef;
    property var promptArray: [];
    property var ollamaModels: [];
    property bool isLoading: false
    property bool hasLocalModel: false;
    property bool disableAutoScroll: false;
    property string currentProvider: Plasmoid.configuration.provider || "ollama"
    property bool thinkingEnabled: true
    property bool isStreaming: false
    property string lastSentMessage: ""
    property var activeXhr: null

    property var providers: {
        try {
            return JSON.parse(Plasmoid.configuration.providers || "[]");
        } catch (e) {
            return [];
        }
    }

    function isProviderConfigured() {
        var lastDash = currentProvider.lastIndexOf("-");
        if (lastDash < 1) return false;
        
        var type = currentProvider.substring(0, lastDash);
        var index = parseInt(currentProvider.substring(lastDash + 1));
        
        var provider = providers[index];
        if (!provider || provider.type !== type) return false;
        
        if (type === "ollama") {
            return hasLocalModel;
        } else if (type === "openclaw") {
            return provider.url && provider.token;
        } else if (type === "openai-compatible") {
            return provider.url && provider.token && provider.model;
        }
        return false;
    }

    function isProviderEnabled(providerId) {
        var lastDash = providerId.lastIndexOf("-");
        if (lastDash < 1) return false;
        
        var type = providerId.substring(0, lastDash);
        var index = parseInt(providerId.substring(lastDash + 1));
        
        var provider = providers[index];
        return provider && provider.type === type && provider.enabled !== false;
    }

    function getFirstAvailableProvider() {
        for (var i = 0; i < providers.length; i++) {
            var provider = providers[i];
            if (provider.enabled === false) continue;
            
            if (provider.type === "ollama" && hasLocalModel) {
                return "ollama-" + i;
            } else if (provider.type === "openclaw" && provider.url && provider.token) {
                return "openclaw-" + i;
            } else if (provider.type === "openai-compatible" && provider.url && provider.token && provider.model) {
                return "openai-compatible-" + i;
            }
        }
        return "ollama-0";
    }

    function getProviderNotConfiguredMessage() {
        var lastDash = currentProvider.lastIndexOf("-");
        if (lastDash < 1) return i18n("Provider not configured.");
        
        var type = currentProvider.substring(0, lastDash);
        var index = parseInt(currentProvider.substring(lastDash + 1));
        var provider = providers[index];
        
        if (type === "ollama") {
            return i18n("No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.");
        } else if (type === "openclaw") {
            return i18n("OpenClaw not configured.\nPlease set URL and Token in settings.");
        } else if (type === "openai-compatible") {
            var name = provider && provider.displayName ? provider.displayName : "OpenAI Compatible";
            return i18n("%1 not configured.\nPlease set URL, Token and Model in settings.", name);
        }
        return i18n("Provider not configured.");
    }

    function getProvider(index) {
        return providers[index];
    }

    function getProviderType() {
        var lastDash = currentProvider.lastIndexOf("-");
        return lastDash > 0 ? currentProvider.substring(0, lastDash) : "ollama";
    }

    function getProviderIndex() {
        var lastDash = currentProvider.lastIndexOf("-");
        return lastDash > 0 ? parseInt(currentProvider.substring(lastDash + 1)) : 0;
    }

    function handleStreaming(text, oldLength, listModel) {
        isStreaming = true;

        if (!disableAutoScroll && scrollViewRef && scrollViewRef.ScrollBar) {
            scrollViewRef.ScrollBar.vertical.position = 1 - scrollViewRef.ScrollBar.vertical.size;
        }

        if (listModel.count === oldLength) {
            listModel.append({
                "name": "Assistant",
                "number": text
            });
        } else {
            const lastValue = listModel.get(oldLength);
            lastValue.number = text;
        }
    }

    function handleRequestComplete(oldLength, listModel) {
        console.log("handleRequestComplete — activeXhr:", activeXhr, "isLoading:", isLoading);
        if (activeXhr === null) {
            console.log("handleRequestComplete — early return (activeXhr null)");
            return;
        }

        if (listModel.count > oldLength) {
            const lastValue = listModel.get(oldLength);
            promptArray.push({ "role": "assistant", "content": lastValue.number, "images": [] });
        }
        isLoading = false;
        activeXhr = null;
        isStreaming = false;
    }

    function cancelRequest() {
        console.log("CANCEL called — isLoading:", isLoading, "isStreaming:", isStreaming, "activeXhr:", activeXhr);
        if (!isLoading) {
            console.log("CANCEL early return — not loading");
            return "";
        }

        var wasStreamingBeforeAbort = isStreaming;
        console.log("wasStreamingBeforeAbort:", wasStreamingBeforeAbort);

        var abortResult = ApiClient.abortActiveRequest();
        console.log("abortActiveRequest returned:", abortResult);
        activeXhr = null;

        var restoreText = "";

        if (!wasStreamingBeforeAbort) {
            if (listModelController.count > 0) {
                listModelController.remove(listModelController.count - 1);
            }
            promptArray.pop();
            restoreText = lastSentMessage;
        }

        isLoading = false;
        isStreaming = false;
        console.log("CANCEL done — isLoading:", isLoading, "isStreaming:", isStreaming);
        return restoreText;
    }
    function stopRequest() {
        if (!isLoading) return;

        ApiClient.abortActiveRequest();
        activeXhr = null;

        
        if (listModelController.count > 0) {
            var lastIndex = listModelController.count - 1;
            var lastItem = listModelController.get(lastIndex);
            if (lastItem && lastItem.name === "Assistant") {
                promptArray.push({ "role": "assistant", "content": lastItem.number, "images": [] });
            }
        }
        
        isLoading = false;
        isStreaming = false;
    }

    function request(prompt) {
        isStreaming = false;
        lastSentMessage = prompt;

        listModelController.append({
            "name": "User",
            "number": prompt
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;

        if (!disableAutoScroll && scrollViewRef && scrollViewRef.ScrollBar) {
            scrollViewRef.ScrollBar.vertical.position = 1;
        }

        var type = getProviderType();
        var index = getProviderIndex();
        var provider = getProvider(index);

        if (type === "ollama") {
            activeXhr = ApiClient.requestOllama(
                currentModel,
                promptArray,
                listModelController,
                handleStreaming,
                handleRequestComplete
            );
        } else if (type === "openclaw") {
            activeXhr = ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                "openclaw",
                promptArray,
                true,
                { "x-openclaw-agent-id": "main" },
                true,
                listModelController,
                handleStreaming,
                handleRequestComplete
            );
        } else if (type === "openai-compatible") {
            activeXhr = ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                provider.model,
                promptArray,
                thinkingEnabled,
                null,
                false,
                listModelController,
                handleStreaming,
                handleRequestComplete
            );
        }
    }

    function getModels() {
        ApiClient.getOllamaModels(
            function(models) {
                if (models.length) {
                    hasLocalModel = true;
                    currentModel = models[0];
                    ollamaModels = models.map(model => ({
                        text: ApiClient.parseTextToComboBox(model),
                        value: model
                    }));
                }
            },
            function(status, statusText) {
                console.error('Error fetching models:', status, statusText);
            }
        );
    }

    function initializeProvider() {
        if (!isProviderEnabled(currentProvider)) {
            currentProvider = getFirstAvailableProvider();
            Plasmoid.configuration.provider = currentProvider;
        }

        if (getProviderType() === "ollama") {
            getModels();
        }
    }

    function getThinkingEnabledForCurrentProvider() {
        var provider = getProvider(getProviderIndex());
        return provider && provider.thinkingEnabled !== undefined ? provider.thinkingEnabled : true;
    }

    Component.onCompleted: {
        initializeProvider();
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Keep Open")
            icon.name: "window-pin"
            checkable: true
            checked: Plasmoid.configuration.pin || false
            onTriggered: Plasmoid.configuration.pin = checked
        },
        PlasmaCore.Action {
            text: i18n("New chat")
            icon.name: "list-add-symbolic"
            onTriggered: {
                listModelController.clear();
                promptArray = [];
            }
        },
        PlasmaCore.Action {
            text: i18n("Disable auto scroll")
            icon.name: "transform-move-vertical"
            checkable: true
            checked: disableAutoScroll
            onTriggered: disableAutoScroll = !disableAutoScroll
        }
    ]

    compactRepresentation: CompactRepresentation {}

    fullRepresentation: ColumnLayout {
        property bool expanded: false

        Layout.preferredHeight: 600
        Layout.preferredWidth: 400
        Layout.fillWidth: true
        Layout.fillHeight: true

        Component.onCompleted: {
            expanded = Qt.binding(function() { return root.expanded; });
        }

        onExpandedChanged: {
            if (expanded) {
                focusTimer.start();
            }
        }

        Timer {
            id: focusTimer
            interval: 100
            onTriggered: {
                messageInput.textField.forceActiveFocus()
            }
        }

        Header {
            id: header

            isLoading: root.isLoading
            currentProvider: root.currentProvider
            currentModel: root.currentModel
            ollamaModels: root.ollamaModels
            providers: root.providers
            thinkingEnabled: root.thinkingEnabled
            listModelController: root.listModelController
            pinChecked: Plasmoid.configuration.pin || false

            onClearChatRequested: {
                listModelController.clear();
                promptArray = [];
            }

            onProviderSelected: function(provider, model) {
                root.currentProvider = provider;
                Plasmoid.configuration.provider = provider;
                if (getProviderType() === "ollama") {
                    root.currentModel = model;
                }
                listModelController.clear();
            }

            onPinToggled: function(checked) {
                Plasmoid.configuration.pin = checked;
            }

            onThinkingToggled: function(enabled) {
                root.thinkingEnabled = enabled;
            }
        }

        ScrollView {
            id: scrollView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            clip: true

            Component.onCompleted: {
                scrollViewRef = scrollView;
            }

            ListView {
                id: listView
                spacing: Kirigami.Units.smallSpacing

                Layout.fillWidth: true
                Layout.fillHeight: true

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    visible: listView.count === 0
                    text: root.isProviderConfigured() ? i18n("I am waiting for your questions...") : root.getProviderNotConfiguredMessage()
                }

                model: ListModel {
                    id: listModel

                    Component.onCompleted: {
                        listModelController = listModel;
                    }
                }

                delegate: ChatMessage {
                    messageText: ApiClient.preprocessMarkdown(number)
                    senderName: name
                }
            }
        }

        MessageInput {
            id: messageInput

            Layout.fillWidth: true

            isProviderConfigured: root.isProviderConfigured()
            isLoading: root.isLoading
            isStreaming: root.isStreaming

            onCancelOrStop: {
                var restoreText = root.cancelRequest();
                if (restoreText) {
                    messageInput.textField.text = restoreText;
                }
            }

            onSendMessage: function(message) {
                if (message.trim()) {
                    root.request(message);
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true

            text: i18n("Refresh models list")
            visible: getProviderType() === "ollama" && !hasLocalModel

            onClicked: getModels()
        }
    }
}
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
    property bool thinkingEnabled: !(Plasmoid.configuration.openaiCompatibleDisableThinking || false)

    property bool enableOllama: Plasmoid.configuration.enableOllama !== false
    property bool enableOpenClaw: Plasmoid.configuration.enableOpenClaw === true
    property bool enableOpenAICompatible: Plasmoid.configuration.enableOpenAICompatible === true

    function isProviderConfigured() {
        if (!isProviderEnabled(currentProvider)) {
            return false;
        }
        if (currentProvider === "ollama") {
            return hasLocalModel;
        } else if (currentProvider === "openclaw") {
            return Plasmoid.configuration.openclawUrl && Plasmoid.configuration.openclawToken;
        } else if (currentProvider === "openai-compatible") {
            return Plasmoid.configuration.openaiCompatibleUrl &&
                   Plasmoid.configuration.openaiCompatibleToken &&
                   Plasmoid.configuration.openaiCompatibleModel;
        }
        return false;
    }

    function isProviderEnabled(provider) {
        if (provider === "ollama") return enableOllama;
        if (provider === "openclaw") return enableOpenClaw;
        if (provider === "openai-compatible") return enableOpenAICompatible;
        return false;
    }

    function getFirstAvailableProvider() {
        if (enableOpenClaw && Plasmoid.configuration.openclawUrl && Plasmoid.configuration.openclawToken) {
            return "openclaw";
        }
        if (enableOpenAICompatible && Plasmoid.configuration.openaiCompatibleUrl &&
            Plasmoid.configuration.openaiCompatibleToken && Plasmoid.configuration.openaiCompatibleModel) {
            return "openai-compatible";
        }
        if (enableOllama && hasLocalModel) {
            return "ollama";
        }
        return "ollama";
    }

    function getProviderNotConfiguredMessage() {
        if (currentProvider === "ollama") {
            return i18n("No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.");
        } else if (currentProvider === "openclaw") {
            return i18n("OpenClaw not configured.\nPlease set URL and Token in settings.");
        } else if (currentProvider === "openai-compatible") {
            return i18n("OpenAI Compatible not configured.\nPlease set URL, Token and Model in settings.");
        }
        return i18n("Provider not configured.");
    }

    function handleStreaming(text, oldLength, listModel) {
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
        if (listModel.count > oldLength) {
            const lastValue = listModel.get(oldLength);
            promptArray.push({ "role": "assistant", "content": lastValue.number, "images": [] });
        }
        isLoading = false;
    }

    function request(prompt) {
        listModelController.append({
            "name": "User",
            "number": prompt
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;

        if (!disableAutoScroll && scrollViewRef && scrollViewRef.ScrollBar) {
            scrollViewRef.ScrollBar.vertical.position = 1;
        }

        if (currentProvider === "ollama") {
            ApiClient.requestOllama(
                currentModel,
                promptArray,
                listModelController,
                handleStreaming,
                handleRequestComplete
            );
        } else if (currentProvider === "openclaw") {
            ApiClient.requestOpenAICompatible(
                Plasmoid.configuration.openclawUrl,
                Plasmoid.configuration.openclawToken,
                "openclaw",
                promptArray,
                true,
                { "x-openclaw-agent-id": "main" },
                true,
                listModelController,
                handleStreaming,
                handleRequestComplete
            );
        } else if (currentProvider === "openai-compatible") {
            ApiClient.requestOpenAICompatible(
                Plasmoid.configuration.openaiCompatibleUrl,
                Plasmoid.configuration.openaiCompatibleToken,
                Plasmoid.configuration.openaiCompatibleModel,
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

        if (currentProvider === "ollama" && enableOllama) {
            getModels();
        }
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
            text: i18n("Clear chat")
            icon.name: "edit-clear"
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
        Layout.preferredHeight: 600
        Layout.preferredWidth: 400
        Layout.fillWidth: true
        Layout.fillHeight: true

        Header {
            id: header

            isLoading: root.isLoading
            currentProvider: root.currentProvider
            currentModel: root.currentModel
            ollamaModels: root.ollamaModels
            enableOllama: root.enableOllama
            enableOpenClaw: root.enableOpenClaw
            enableOpenAICompatible: root.enableOpenAICompatible
            openaiCompatibleModelName: Plasmoid.configuration.openaiCompatibleModel
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
                if (provider === "ollama") {
                    root.currentModel = model;
                }
                listModelController.clear();
            }

            onPinToggled: function(checked) {
                Plasmoid.configuration.pin = checked;
            }

            onThinkingToggled: function(enabled) {
                Plasmoid.configuration.openaiCompatibleDisableThinking = !enabled;
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
            visible: enableOllama && currentProvider === "ollama" && !hasLocalModel

            onClicked: getModels()
        }
    }
}
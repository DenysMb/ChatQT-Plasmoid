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
import org.kde.plasma.extras as PlasmaExtras

PlasmoidItem {
    id: root

    property string parentMessageId: ''
    property string modelsComboboxCurrentValue: '';    
    property var listModelController;
    property var promptArray: [];
    property var modelsArray: [];
    property bool isLoading: false
    property bool hasLocalModel: false;
    property bool disableAutoScroll: false;
    property string currentProvider: Plasmoid.configuration.provider || "ollama"

    function isProviderConfigured() {
        const provider = currentProvider;
        if (provider === "ollama") {
            return hasLocalModel;
        } else if (provider === "openclaw") {
            return Plasmoid.configuration.openclawUrl && Plasmoid.configuration.openclawToken;
        } else if (provider === "openai-compatible") {
            return Plasmoid.configuration.openaiCompatibleUrl && 
                   Plasmoid.configuration.openaiCompatibleToken && 
                   Plasmoid.configuration.openaiCompatibleModel;
        }
        return false;
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

    function parseTextToComboBox(text) {
        return text
            .replace(/-/g, ' ')
            .replace(/:(.+)/, ' ($1)')
            .split(' ')
            .map(word => {
                if (word.startsWith('(')) {
                    return word.charAt(0) + word.charAt(1).toUpperCase() + word.slice(2);
                }
                return word.charAt(0).toUpperCase() + word.slice(1);
            })
            .join(' ');
    }

    function requestOllama(messageField, listModel, scrollView, prompt) {
        const oldLength = listModel.count;
        const url = 'http://127.0.0.1:11434/api/chat';
        const data = JSON.stringify({
            "model": modelsComboboxCurrentValue,
            "keep_alive": "5m",
            "options": {},
            "messages": promptArray
        });
        
        let xhr = new XMLHttpRequest();

        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.onreadystatechange = function() {
            const objects = xhr.responseText.split('\n');
            let text = '';

            objects.forEach((object, index) => {
                try {
                    const parsedObject = JSON.parse(object);
                    text = text + (parsedObject?.message?.content || '');

                    if (index === 0) {
                        text = text.trim();
                    }

                    if (!disableAutoScroll && scrollView.ScrollBar) {
                        scrollView.ScrollBar.vertical.position = 1 - scrollView.ScrollBar.vertical.size;
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
                } catch (e) {
                    // Skip invalid JSON
                }
            });
        };

        xhr.onload = function() {
            if (listModel.count > oldLength) {
                const lastValue = listModel.get(oldLength);
                promptArray.push({ "role": "assistant", "content": lastValue.number, "images": [] });
            }
            isLoading = false;
        };

        xhr.send(data);
    }

    function requestOpenAICompatible(baseUrl, token, model, messageField, listModel, scrollView, prompt, extraHeaders) {
        const oldLength = listModel.count;
        const url = baseUrl.replace(/\/$/, '') + '/v1/chat/completions';
        const data = JSON.stringify({
            "model": model,
            "messages": promptArray,
            "stream": true
        });
        
        let xhr = new XMLHttpRequest();

        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.setRequestHeader('Authorization', 'Bearer ' + token);
        
        if (extraHeaders) {
            for (const [key, value] of Object.entries(extraHeaders)) {
                xhr.setRequestHeader(key, value);
            }
        }

        let text = '';
        let processedLength = 0;

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
                const response = xhr.responseText;
                
                if (response.length > processedLength) {
                    const newChunk = response.substring(processedLength);
                    processedLength = response.length;
                    
                    const lines = newChunk.split('\n');
                    
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim();
                        
                        if (line.startsWith('data: ')) {
                            const dataStr = line.substring(6);
                            
                            if (dataStr === '[DONE]') {
                                continue;
                            }
                            
                            try {
                                const parsed = JSON.parse(dataStr);
                                const choices = parsed.choices;
                                if (choices && choices.length > 0) {
                                    const delta = choices[0].delta;
                                    if (delta && delta.content) {
                                        text += delta.content;
                                        
                                        if (!disableAutoScroll && scrollView.ScrollBar) {
                                            scrollView.ScrollBar.vertical.position = 1 - scrollView.ScrollBar.vertical.size;
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
                                }
                            } catch (e) {
                                // Skip invalid JSON
                            }
                        }
                    }
                }
            }

            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (listModel.count > oldLength) {
                    const lastValue = listModel.get(oldLength);
                    promptArray.push({ "role": "assistant", "content": lastValue.number, "images": [] });
                }
                isLoading = false;
            }
        };

        xhr.send(data);
    }

    function request(messageField, listModel, scrollView, prompt) {
        messageField.text = '';

        listModel.append({
            "name": "User",
            "number": prompt
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;

        if (!disableAutoScroll && scrollView.ScrollBar) {
            scrollView.ScrollBar.vertical.position = 1;
        }

        const provider = currentProvider;

        if (provider === "ollama") {
            requestOllama(messageField, listModel, scrollView, prompt);
        } else if (provider === "openclaw") {
            const url = Plasmoid.configuration.openclawUrl;
            const token = Plasmoid.configuration.openclawToken;
            requestOpenAICompatible(url, token, "openclaw", messageField, listModel, scrollView, prompt, {
                "x-openclaw-agent-id": "main"
            });
        } else if (provider === "openai-compatible") {
            const url = Plasmoid.configuration.openaiCompatibleUrl;
            const token = Plasmoid.configuration.openaiCompatibleToken;
            const model = Plasmoid.configuration.openaiCompatibleModel;
            requestOpenAICompatible(url, token, model, messageField, listModel, scrollView, prompt);
        }
    }

    function getModels() {
        const url = 'http://127.0.0.1:11434/api/tags';

        let xhr = new XMLHttpRequest();

        xhr.open('GET', url);
        xhr.setRequestHeader('Content-Type', 'application/json');

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    const objects = JSON.parse(xhr.responseText).models;
                    
                    const models = objects.map(object => object.model);

                    if (models.length) {
                        hasLocalModel = true;

                        modelsComboboxCurrentValue = models[0];

                        modelsArray = models.map(model => ({ text: parseTextToComboBox(model), value: model }));
                    }
                } else {
                    console.error('Erro na requisição:', xhr.status, xhr.statusText);
                }
            }
        };

        xhr.send();
    }

    Component.onCompleted: {
        if (currentProvider === "ollama") {
            getModels();
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Keep Open")
            icon.name: "window-pin"
            checkable: true
            checked: Plasmoid.configuration.pin
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
        Layout.preferredHeight: 400
        Layout.preferredWidth: 350
        Layout.fillWidth: true
        Layout.fillHeight: true

        PlasmaExtras.PlasmoidHeading {
            width: parent.width

            contentItem: RowLayout {
                visible: isProviderConfigured()
                Layout.fillWidth: true

                PlasmaComponents.Button {
                    id: pinButton
                    checkable: true
                    checked: Plasmoid.configuration.pin
                    onToggled: Plasmoid.configuration.pin = checked
                    icon.name: "window-pin"

                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Keep Open")

                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents.ToolTip.visible: hovered
                }

                PlasmaComponents.ComboBox {
                    id: modelsCombobox
                    visible: currentProvider === "ollama"
                    enabled: hasLocalModel && !isLoading
                    hoverEnabled: hasLocalModel && !isLoading

                    Layout.fillWidth: true

                    model: modelsArray.map(model => model.text)

                    onActivated: {
                        modelsComboboxCurrentValue = modelsArray.find(model => model.text === modelsCombobox.currentText).value;
                        listModelController.clear();
                    }
                }

                PlasmaComponents.Label {
                    visible: currentProvider === "openclaw"
                    Layout.fillWidth: true
                    text: "OpenClaw"
                    horizontalAlignment: Text.AlignHCenter
                }

                PlasmaComponents.Label {
                    visible: currentProvider === "openai-compatible"
                    Layout.fillWidth: true
                    text: Plasmoid.configuration.openaiCompatibleModel || "OpenAI Compatible"
                    horizontalAlignment: Text.AlignHCenter
                }

                PlasmaComponents.Button {
                    icon.name: "edit-clear-symbolic"
                    text: i18n("Clear chat")
                    display: PlasmaComponents.AbstractButton.IconOnly
                    enabled: isProviderConfigured() && !isLoading
                    hoverEnabled: isProviderConfigured() && !isLoading

                    onClicked: {
                        listModelController.clear();
                    }

                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents.ToolTip.visible: hovered
                }
            }
        }

        ScrollView {
            id: scrollView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            clip: true

            ListView {
                id: listView
                spacing: Kirigami.Units.smallSpacing

                Layout.fillWidth: true
                Layout.fillHeight: true

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    visible: listView.count === 0
                    text: isProviderConfigured() ? i18n("I am waiting for your questions...") : getProviderNotConfiguredMessage()
                }

                model: ListModel {
                    id: listModel

                    Component.onCompleted: {
                        listModelController = listModel;
                    }
                }

                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    implicitHeight: 24 + textMessage.implicitHeight

                    contentItem: TextEdit {
                        id: textMessage

                        topPadding: 8
                        readOnly: true
                        wrapMode: Text.WordWrap
                        text: number
                        color: name === "User" ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                        selectByMouse: true

                        PlasmaComponents.Button {
                            anchors.right: parent.right

                            icon.name: "edit-copy-symbolic"
                            text: i18n("Copy")
                            display: PlasmaComponents.AbstractButton.IconOnly
                            visible: hoverHandler.hovered
                            
                            onClicked: {
                                textMessage.selectAll();
                                textMessage.copy();
                                textMessage.deselect();
                            }

                            PlasmaComponents.ToolTip.text: text
                            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents.ToolTip.visible: hovered
                        }

                        HoverHandler {
                            id: hoverHandler
                        }
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            clip: true
            visible: isProviderConfigured()

            TextArea {
                id: messageField

                Layout.fillWidth: true
                Layout.fillHeight: true

                enabled: isProviderConfigured() && !isLoading
                hoverEnabled: isProviderConfigured() && !isLoading
                placeholderText: i18n("Type here what you want to ask...")
                wrapMode: TextArea.Wrap

                Keys.onReturnPressed: {
                    if (event.modifiers & Qt.ControlModifier) {
                        request(messageField, listModel, scrollView, messageField.text);
                    } else {
                        event.accepted = false;
                    }
                }

                BusyIndicator {
                    id: indicator
                    anchors.centerIn: parent
                    running: isLoading
                }
            }

        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            
            text: i18n("Send")
            hoverEnabled: isProviderConfigured() && !isLoading
            enabled: isProviderConfigured() && !isLoading
            visible: isProviderConfigured()

            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: "CTRL+Enter"
            
            onClicked: {
                request(messageField, listModel, scrollView, messageField.text);
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            
            text: i18n("Refresh models list")
            visible: currentProvider === "ollama" && !hasLocalModel
            
            onClicked: getModels()
        }
    }
}

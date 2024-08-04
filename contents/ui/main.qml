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

    function request(messageField, listModel, scrollView, prompt) {
        messageField.text = '';

        listModel.append({
            "name": "User",
            "number": prompt
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;

        if (scrollView.ScrollBar) {
            scrollView.ScrollBar.vertical.position = 1;
        }

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

            objects.forEach(object => {
                const parsedObject = JSON.parse(object);
                text = text + parsedObject?.message?.content;

                if (scrollView.ScrollBar) {
                    scrollView.ScrollBar.vertical.position = 1 - scrollView.ScrollBar.vertical.size;
                }

                if (listModel.count === oldLength) {
                    listModel.append({
                        "name": "ChatGPT",
                        "number": text
                    });
                } else {
                    const lastValue = listModel.get(oldLength);

                    lastValue.number = text;
                }
            });
        };

        xhr.onload = function() {
            const lastValue = listModel.get(oldLength);

            isLoading = false;

            promptArray.push({ "role": "assistant", "content": lastValue.number, "images": [] });
        };

        xhr.send(data);
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

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Keep Open")
            icon.name: "window-pin"
            priority: Plasmoid.LowPriorityAction
            checkable: true
            checked: plasmoid.configuration.pin
            onTriggered: plasmoid.configuration.pin = checked
        },
        PlasmaCore.Action {
            text: i18n("Clear chat")
            icon.name: "edit-clear"
            onTriggered: {
                listModelController.clear();
                promptArray = [];
            }
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
                visible: hasLocalModel
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
                    enabled: hasLocalModel && !isLoading
                    hoverEnabled: hasLocalModel && !isLoading

                    Layout.fillWidth: true

                    model: modelsArray.map(model => model.text)

                    onActivated: {
                        modelsComboboxCurrentValue = modelsArray.find(model => model.text === modelsCombobox.currentText).value;
                        listModelController.clear();
                    }

                    Component.onCompleted: getModels()
                }

                PlasmaComponents.Button {
                    icon.name: "edit-clear-symbolic"
                    text: "Clear chat"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    enabled: hasLocalModel && !isLoading
                    hoverEnabled: hasLocalModel && !isLoading

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

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    visible: listView.count === 0
                    text: i18n(hasLocalModel ? "I am waiting for your questions..." : "No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.")
                }

                model: ListModel {
                    id: listModel

                    Component.onCompleted: {
                        listModelController = listModel;
                    }
                }

                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true

                    contentItem: TextEdit {
                        readOnly: true
                        wrapMode: Text.WordWrap
                        text: number
                        color: name === "User" ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                        selectByMouse: true
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            clip: true
            visible: hasLocalModel

            TextArea {
                id: messageField

                Layout.fillWidth: true
                Layout.fillHeight: true

                enabled: hasLocalModel && !isLoading
                hoverEnabled: hasLocalModel && !isLoading
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
            
            text: "Send"
            hoverEnabled: hasLocalModel && !isLoading
            enabled: hasLocalModel && !isLoading
            visible: hasLocalModel

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
            
            text: "Refresh models list"
            visible: !hasLocalModel
            
            onClicked: getModels()
        }
    }
}

/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.1
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.19 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.core 2.1 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: root

    property string parentMessageId: ''
    property var listModelController;
    property var messageField;

    function request(messageField, listModel, scrollView, prompt) {
        messageField.text = '';

        listModel.append({
            "name": "User",
            "number": prompt
        });

        if (scrollView.ScrollBar) {
            scrollView.ScrollBar.vertical.position = 1;
        }

        const oldLength = listModel.count;
        const url = 'https://chatbot.theb.ai/api/chat-process';
        const data = JSON.stringify({
            "prompt": prompt,
            "options": {
                "parentMessageId": parentMessageId
            }
        });
        
        let xhr = new XMLHttpRequest();

        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.onreadystatechange = function() {
            const objects = xhr.responseText.split('\n');
            const lastObject = objects[objects.length - 1];
            const parsedObject = JSON.parse(lastObject);
            const text = parsedObject.text;

            parentMessageId = parsedObject.id;

            if (scrollView.ScrollBar) {
                scrollView.ScrollBar.vertical.position = 1 - scrollView.ScrollBar.vertical.size;
            }

            if (listModel.count === oldLength) {
                listModel.append({
                    "name": "ChatGTP",
                    "number": text
                });
            } else {
                const lastValue = listModel.get(oldLength);

                lastValue.number = text;
            }
        };

        xhr.send(data);
    }

    function action_clearChat() {
        listModelController.clear();
    }

    Timer {
        id: messageFieldActiveFocusTimer
        interval: 100
        onTriggered: {
            messageField.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        Plasmoid.setAction("clearChat", i18n("Clear chat"), "edit-clear");
    }

    Plasmoid.compactRepresentation: CompactRepresentation {}

    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.preferredHeight: 400
        Layout.preferredWidth: 350
        Layout.fillWidth: true
        Layout.fillHeight: true

        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true

                Kirigami.Heading {
                    Layout.fillWidth: true
                    color: PlasmaCore.Theme.textColor
                    text: "ChatQTP"
                }

                PlasmaComponents.ToolButton {
                    checkable: true
                    checked: plasmoid.configuration.pin
                    icon.name: "window-pin"
                    text: i18n("Keep Open")
                    display: PlasmaComponents.ToolButton.IconOnly
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents.ToolTip.visible: hovered
                    onToggled: plasmoid.configuration.pin = checked
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
                spacing: Kirigami.Units.mediumSpacing

                Kirigami.Heading {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: listView.count === 0
                    text: i18n("I am waiting for your questions...")
                    color: PlasmaCore.Theme.textColor
                    opacity: 0.75
                }

                model: ListModel {
                    id: listModel

                    Component.onCompleted: {
                        listModelController = listModel;
                    }
                }

                delegate: Kirigami.AbstractCard {
                    id: abstractCard
                    Kirigami.Theme.colorSet: Kirigami.Theme.Selection
                    Layout.fillWidth: true
                    opacity: name === "User" ? 0.5 : 0.75

                    contentItem: RowLayout {
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        TextEdit {
                            id: textEdit
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            readOnly: true
                            wrapMode: Text.WordWrap
                            text: number
                            color: name === "User" ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                            selectByMouse: true
                        }
                        
                        PlasmaComponents.Button {
                            flat: true
                            Layout.alignment: Qt.AlignTop
                            opacity: hovered ? 1 : 0.5
                            hoverEnabled: true
                            icon.name: "edit-copy"
                            ToolTip.delay: 1000
                            ToolTip.visible: hovered
                            ToolTip.text: "Copy"
                            onClicked: {
                                textEdit.selectAll();
                                textEdit.copy();
                                textEdit.deselect();
                            }
                        }
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            clip: true

            PlasmaComponents.TextArea {
                id: messageField
                activeFocusOnTab: true

                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: i18n("Type here what you want to ask...")
                Keys.onReturnPressed: {
                    if (event.modifiers & Qt.ControlModifier) {
                        request(messageField, listModel, scrollView, messageField.text);
                    } else {
                        event.accepted = false;
                    }
                }

                Component.onCompleted: {
                    root.messageField = messageField;
                    messageFieldActiveFocusTimer.start();
                }
            }

        }

        PlasmaComponents.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: "Send"
            hoverEnabled: true
            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: "CTRL+Enter"
            onClicked: {
                request(messageField, listModel, scrollView, messageField.text);
            }
        }
    }
}

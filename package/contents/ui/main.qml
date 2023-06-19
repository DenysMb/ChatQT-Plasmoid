/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.1
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.19 as Kirigami
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0

Item {
    property string parentMessageId: ''

    function request(messageField, listModel, scrollView, prompt) {
        messageField.text = '';
        listModel.append({
            "name": "User",
            "number": prompt
        });
        var url = 'https://chatbot.theb.ai/api/chat-process';
        var data = JSON.stringify({
            "prompt": prompt,
            "options": {
                "parentMessageId": parentMessageId
            }
        });
        var xhr = new XMLHttpRequest();
        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.onreadystatechange = function() {
            const objects = xhr.responseText.split('\n');
            const lastObject = objects[objects.length - 1];
            const parsedObject = JSON.parse(lastObject);
            const text = parsedObject.text;
            parentMessageId = parsedObject.id;
            if (scrollView.ScrollBar)
                scrollView.ScrollBar.vertical.position = 1 - scrollView.ScrollBar.vertical.size;

            if (xhr.readyState === 4 && xhr.status === 200)
                listModel.append({
                "name": "ChatGTP",
                "number": text
            });

        };
        xhr.send(data);
    }

    function action_clearChat() {
        listModel.clear();
    }

    Component.onCompleted: {
        Plasmoid.setAction("clearChat", i18n("Clear chat"), "edit-clear");
    }

    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.preferredHeight: 400
        Layout.preferredWidth: 350
        Layout.fillWidth: true
        Layout.fillHeight: true

        ScrollView {
            id: scrollView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            clip: true
            rightPadding: 0

            ListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    visible: listView.count === 0
                    text: i18n("I am waiting for your questions...")
                }

                model: ListModel {
                    id: listModel
                }

                delegate: Text {
                    width: parent.width
                    Layout.fillWidth: true
                    text: name + ": " + number
                    wrapMode: Text.Wrap
                    color: name === "User" ? "green" : "red"
                }

            }

        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100
            clip: true
            rightPadding: 0

            TextArea {
                id: messageField

                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: i18n("Type here what you want to ask...")
                Keys.onReturnPressed: {
                    if (event.modifiers & Qt.ControlModifier)
                        request(messageField, listModel, scrollView, messageField.text);
                    else
                        event.accepted = false;
                }
            }

        }

        Button {
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

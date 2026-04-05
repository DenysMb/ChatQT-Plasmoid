/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    signal sendMessage(string message)
    signal cancelOrStop()

    property alias textField: messageField

    property bool isProviderConfigured: false
    property bool isLoading: false
    property bool isStreaming: false

    spacing: Kirigami.Units.smallSpacing

    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        clip: true
        visible: root.isProviderConfigured

        TextArea {
            id: messageField

            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true
            enabled: root.isProviderConfigured
            hoverEnabled: root.isProviderConfigured
            readOnly: root.isLoading
            placeholderText: i18n("Type here what you want to ask...")
            wrapMode: TextArea.Wrap

            Keys.onReturnPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                    if (root.isLoading) {
                        root.cancelOrStop()
                        event.accepted = true
                    } else {
                        root.sendMessage(messageField.text)
                        messageField.text = ''
                    }
                } else {
                    event.accepted = false;
                }
            }

            BusyIndicator {
                id: indicator
                anchors.centerIn: parent
                running: root.isLoading
            }
        }
    }

    Button {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true

        text: root.isLoading ? (root.isStreaming ? i18n("Stop") : i18n("Cancel")) : i18n("Send")
        icon.name: root.isLoading ? "process-stop" : "document-send"
        hoverEnabled: root.isProviderConfigured
        enabled: root.isProviderConfigured
        visible: root.isProviderConfigured

        ToolTip.delay: 1000
        ToolTip.visible: hovered
        ToolTip.text: root.isLoading ? i18n("Cancel or stop the current request (Ctrl+Enter)") : i18n("Ctrl+Enter")

        onClicked: {
            if (root.isLoading) {
                root.cancelOrStop()
            } else if (messageField.text.trim()) {
                root.sendMessage(messageField.text)
                messageField.text = ''
            }
        }
    }
}
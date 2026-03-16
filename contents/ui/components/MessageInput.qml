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

    property bool isProviderConfigured: false
    property bool isLoading: false

    spacing: 0

    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        clip: true
        visible: root.isProviderConfigured

        TextArea {
            id: messageField

            Layout.fillWidth: true
            Layout.fillHeight: true

            enabled: root.isProviderConfigured && !root.isLoading
            hoverEnabled: root.isProviderConfigured && !root.isLoading
            placeholderText: i18n("Type here what you want to ask...")
            wrapMode: TextArea.Wrap

            Keys.onReturnPressed: {
                if (event.modifiers & Qt.ControlModifier) {
                    root.sendMessage(messageField.text)
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

        text: i18n("Send")
        hoverEnabled: root.isProviderConfigured && !root.isLoading
        enabled: root.isProviderConfigured && !root.isLoading
        visible: root.isProviderConfigured

        ToolTip.delay: 1000
        ToolTip.visible: hovered
        ToolTip.text: "CTRL+Enter"

        onClicked: {
            if (messageField.text.trim()) {
                root.sendMessage(messageField.text)
            }
        }
    }

    function clearText() {
        messageField.text = ''
    }

    function getText() {
        return messageField.text
    }
}
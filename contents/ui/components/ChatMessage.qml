/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Kirigami.AbstractCard {
    id: root

    property string messageText: ""
    property string senderName: ""

    signal copyRequested(string text)

    Layout.fillWidth: true
    implicitHeight: 24 + textMessage.implicitHeight

    contentItem: TextEdit {
        id: textMessage

        topPadding: 8
        readOnly: true
        wrapMode: Text.WordWrap
        text: root.messageText
        textFormat: TextEdit.MarkdownText
        color: root.senderName === "User" ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
        selectByMouse: true
        onLinkActivated: function(link) {
            Qt.openUrlExternally(link)
        }

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
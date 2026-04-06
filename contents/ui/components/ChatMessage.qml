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
    property string thinkingText: ""
    property bool thinkingExpanded: false

    readonly property bool isUser: senderName === "User"

    Layout.fillWidth: true

    showClickFeedback: false

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Label {
            text: root.senderName
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: root.isUser ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
        }

        ColumnLayout {
            visible: root.thinkingText !== ""
            spacing: Kirigami.Units.smallSpacing

            AbstractButton {
                Layout.fillWidth: true
                implicitHeight: thinkingHeaderLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

                contentItem: RowLayout {
                    id: thinkingHeaderLayout
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: root.thinkingExpanded ? "arrow-down" : "arrow-right"
                        implicitWidth: Kirigami.Units.mediumSpacing
                        implicitHeight: Kirigami.Units.mediumSpacing
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n("Thinking...")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                onClicked: root.thinkingExpanded = !root.thinkingExpanded
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: root.thinkingExpanded ? thinkingContentText.implicitHeight : 0
                clip: true

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }

                Text {
                    id: thinkingContentText
                    width: parent.width
                    text: root.thinkingText
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.Wrap
                }
            }
        }

        TextEdit {
            id: textMessage

            Layout.fillWidth: true

            topPadding: Kirigami.Units.smallSpacing
            bottomPadding: Kirigami.Units.smallSpacing

            readOnly: true
            wrapMode: TextEdit.WordWrap
            text: root.messageText
            textFormat: TextEdit.MarkdownText
            color: root.isUser ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
            selectByMouse: true

            onLinkActivated: function(link) {
                Qt.openUrlExternally(link)
            }
        }
    }

    PlasmaComponents.Button {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.smallSpacing

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
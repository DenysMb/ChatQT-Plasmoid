/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property string serverDisplayName
    property string serverUrl
    property string serverToken
    property bool serverEnabled
    property string serverStatus: "disconnected"
    property int serverToolCount: 0

    signal editClicked
    signal removeClicked
    signal enabledToggled(bool newEnabled)
    signal connectClicked
    signal disconnectClicked

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                checked: root.serverEnabled
                onToggled: root.enabledToggled(checked)
                display: QQC2.AbstractButton.IconOnly
            }

            Kirigami.Heading {
                level: 3
                text: root.serverDisplayName != "" ? root.serverDisplayName : i18nc("@info", "Unnamed MCP Server")
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.serverToolCount > 0 && root.serverStatus === "connected"
                radius: Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 1.2
                width: toolCountLabel.width + Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.positiveTextColor
                Layout.alignment: Qt.AlignVCenter

                QQC2.Label {
                    id: toolCountLabel
                    anchors.centerIn: parent
                    text: root.serverToolCount
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.backgroundColor
                }
            }

            QQC2.ToolButton {
                icon.name: root.serverStatus === "connected" ? "network-disconnect" : "network-connect"
                display: QQC2.AbstractButton.IconOnly
                text: root.serverStatus === "connected" ? i18nc("@action:button", "Disconnect") : i18nc("@action:button", "Connect")
                onClicked: root.serverStatus === "connected" ? root.disconnectClicked() : root.connectClicked()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }

            QQC2.ToolButton {
                icon.name: "document-edit-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Edit")
                onClicked: root.editClicked()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }

            QQC2.ToolButton {
                icon.name: "delete-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Remove")
                onClicked: root.removeClicked()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            opacity: root.serverEnabled ? 1.0 : 0.5
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18nc("@label", "Status:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: {
                        if (root.serverStatus === "connected") return i18nc("@info", "Connected")
                        if (root.serverStatus === "connecting") return i18nc("@info", "Connecting…")
                        if (root.serverStatus === "error") return i18nc("@info", "Error")
                        return i18nc("@info", "Disconnected")
                    }
                    font: Kirigami.Theme.smallFont
                    color: {
                        if (root.serverStatus === "connected") return Kirigami.Theme.positiveTextColor
                        if (root.serverStatus === "connecting") return Kirigami.Theme.neutralTextColor
                        if (root.serverStatus === "error") return Kirigami.Theme.negativeTextColor
                        return Kirigami.Theme.disabledTextColor
                    }
                }

                QQC2.BusyIndicator {
                    visible: root.serverStatus === "connecting"
                    running: root.serverStatus === "connecting"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    text: i18nc("@label", "URL:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: root.serverUrl != "" ? root.serverUrl : i18nc("@info", "Not set")
                    font: Kirigami.Theme.defaultFont
                    color: root.serverUrl != "" ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.ElideMiddle
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    text: i18nc("@label", "Token:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: root.serverToken != ""
                        ? i18nc("@info", "Configured")
                        : i18nc("@info", "Not set")
                    font: Kirigami.Theme.defaultFont
                    color: root.serverToken != "" ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                visible: root.serverStatus === "connected"

                QQC2.Label {
                    text: i18nc("@label", "Tools:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: i18nc("@info", "%1 tool(s) available").arg(root.serverToolCount)
                    font: Kirigami.Theme.defaultFont
                    color: Kirigami.Theme.positiveTextColor
                    Layout.fillWidth: true
                }
            }
        }
    }
}

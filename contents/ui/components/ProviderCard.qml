/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property string providerDisplayName
    property string providerUrl
    property string providerToken
    property string providerModel
    property string providerType
    property bool providerEnabled

    signal editClicked
    signal removeClicked
    signal enabledToggled(bool newEnabled)

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // Title row: checkbox | display name | toolbar actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                checked: root.providerEnabled
                onToggled: root.enabledToggled(checked)
                display: QQC2.AbstractButton.IconOnly
            }

            Kirigami.Heading {
                level: 3
                text: root.providerDisplayName != "" ? root.providerDisplayName : i18nc("@info", "Unnamed Provider")
                Layout.fillWidth: true
                elide: Text.ElideRight
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

        // Provider info section — dimmed when disabled
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            opacity: root.providerEnabled ? 1.0 : 0.5
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    text: i18nc("@label", "URL:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: root.providerUrl != "" ? root.providerUrl : i18nc("@info", "Not set")
                    font: Kirigami.Theme.defaultFont
                    color: root.providerUrl != "" ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.ElideMiddle
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                visible: root.providerType === "openai-compatible" || root.providerType === "ollama"

                QQC2.Label {
                    text: i18nc("@label", "Model:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: root.providerModel != "" ? root.providerModel : (root.providerType === "ollama" ? i18nc("@info", "Auto-detected") : i18nc("@info", "Not set"))
                    font: Kirigami.Theme.defaultFont
                    color: root.providerModel != "" || root.providerType === "ollama" ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
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
                    text: root.providerToken != ""
                        ? i18nc("@info", "Configured — API key is saved securely")
                        : i18nc("@info", "Missing — no API key configured")
                    font: Kirigami.Theme.defaultFont
                    color: root.providerToken != "" ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}

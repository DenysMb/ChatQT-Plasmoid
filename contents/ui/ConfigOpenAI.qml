/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_openaiCompatibleUrl: openaiCompatibleUrlField.text
    property alias cfg_openaiCompatibleToken: openaiCompatibleTokenField.text
    property alias cfg_openaiCompatibleModel: openaiCompatibleModelField.text
    property alias cfg_openaiCompatibleDisableThinking: disableThinkingCheckBox.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "OpenAI Compatible Configuration")
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: openaiCompatibleUrlField

            Kirigami.FormData.label: i18nc("@title:group", "API URL:")
            text: plasmoid.configuration.openaiCompatibleUrl || ""
            placeholderText: "https://api.openai.com/v1"
        }

        QQC2.Label {
            text: i18nc("@info", "The base URL of the OpenAI-compatible API")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        QQC2.TextField {
            id: openaiCompatibleTokenField

            Kirigami.FormData.label: i18nc("@title:group", "API Token:")
            text: plasmoid.configuration.openaiCompatibleToken || ""
            placeholderText: i18nc("@info:placeholder", "Enter your API token")
            echoMode: QQC2.TextField.Password
        }

        QQC2.Label {
            text: i18nc("@info", "Your API key/token for authentication")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        QQC2.TextField {
            id: openaiCompatibleModelField

            Kirigami.FormData.label: i18nc("@title:group", "Model:")
            text: plasmoid.configuration.openaiCompatibleModel || ""
            placeholderText: "gpt-4"
        }

        QQC2.Label {
            text: i18nc("@info", "The model name to use (e.g., gpt-4, gpt-3.5-turbo, deepseek-chat)")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        QQC2.CheckBox {
            id: disableThinkingCheckBox

            Kirigami.FormData.label: i18nc("@title:group", "Thinking Mode:")
            text: i18nc("@option:check", "Disable thinking/reasoning mode")
            checked: plasmoid.configuration.openaiCompatibleDisableThinking || false
        }

        QQC2.Label {
            text: i18nc("@info", "Disable thinking for faster responses (useful for non-reasoning models)")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
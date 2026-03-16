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

    property alias cfg_enableOllama: enableOllamaCheckBox.checked
    property alias cfg_enableOpenClaw: enableOpenClawCheckBox.checked
    property alias cfg_enableOpenAICompatible: enableOpenAICompatibleCheckBox.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Providers")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: enableOllamaCheckBox

            Kirigami.FormData.label: i18nc("@title:group", "Ollama:")
            text: i18nc("@option:check", "Enable")
            checked: plasmoid.configuration.enableOllama !== false
        }

        QQC2.Label {
            text: i18nc("@info", "Local LLM provider. Requires Ollama installed and running.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.CheckBox {
            id: enableOpenClawCheckBox

            Kirigami.FormData.label: i18nc("@title:group", "OpenClaw:")
            text: i18nc("@option:check", "Enable")
            checked: plasmoid.configuration.enableOpenClaw === true
        }

        QQC2.Label {
            text: i18nc("@info", "Self-hosted AI assistant. Configure URL and token in the OpenClaw page.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.CheckBox {
            id: enableOpenAICompatibleCheckBox

            Kirigami.FormData.label: i18nc("@title:group", "OpenAI Compatible:")
            text: i18nc("@option:check", "Enable")
            checked: plasmoid.configuration.enableOpenAICompatible === true
        }

        QQC2.Label {
            text: i18nc("@info", "Any OpenAI-compatible API (OpenAI, DeepSeek, Groq, etc.). Configure in the OpenAI Compatible page.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
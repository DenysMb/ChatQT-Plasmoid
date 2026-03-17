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

    property string cfg_iconStyle: Plasmoid.configuration.iconStyle
    property string cfg_iconStyleDefault: "filled-adaptive"
    property bool cfg_enableOllama: Plasmoid.configuration.enableOllama
    property bool cfg_enableOllamaDefault: true
    property bool cfg_enableOpenClaw: Plasmoid.configuration.enableOpenClaw
    property bool cfg_enableOpenClawDefault: false
    property bool cfg_enableOpenAICompatible: Plasmoid.configuration.enableOpenAICompatible
    property bool cfg_enableOpenAICompatibleDefault: false
    property string cfg_provider: Plasmoid.configuration.provider
    property string cfg_providerDefault: "ollama"
    property string cfg_openclawUrl: Plasmoid.configuration.openclawUrl
    property string cfg_openclawUrlDefault: "http://127.0.0.1:18789"
    property string cfg_openclawToken: Plasmoid.configuration.openclawToken
    property string cfg_openclawTokenDefault: ""
    property string cfg_openaiCompatibleUrl: Plasmoid.configuration.openaiCompatibleUrl
    property string cfg_openaiCompatibleUrlDefault: ""
    property string cfg_openaiCompatibleToken: Plasmoid.configuration.openaiCompatibleToken
    property string cfg_openaiCompatibleTokenDefault: ""
    property string cfg_openaiCompatibleModel: Plasmoid.configuration.openaiCompatibleModel
    property string cfg_openaiCompatibleModelDefault: ""
    property bool cfg_openaiCompatibleDisableThinking: Plasmoid.configuration.openaiCompatibleDisableThinking
    property bool cfg_openaiCompatibleDisableThinkingDefault: false
    property bool cfg_pin: Plasmoid.configuration.pin
    property bool cfg_pinDefault: false

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: enableOllamaCheckBox

            Kirigami.FormData.label: i18nc("@title:group", "Ollama:")

            text: i18nc("@option:check", "Enable")
            checked: cfg_enableOllama
            onCheckedChanged: cfg_enableOllama = checked
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
            checked: cfg_enableOpenClaw
            onCheckedChanged: cfg_enableOpenClaw = checked
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
            checked: cfg_enableOpenAICompatible
            onCheckedChanged: cfg_enableOpenAICompatible = checked
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
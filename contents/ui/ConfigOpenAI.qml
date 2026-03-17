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
        QQC2.TextField {
            id: openaiCompatibleUrlField

            Kirigami.FormData.label: i18nc("@label:textbox", "API URL:")

            Layout.fillWidth: true
            text: cfg_openaiCompatibleUrl
            onTextChanged: cfg_openaiCompatibleUrl = text
            placeholderText: "https://api.openai.com/v1"
        }

        QQC2.Label {
            text: i18nc("@info", "The base URL of the OpenAI-compatible API")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: openaiCompatibleTokenField

            Kirigami.FormData.label: i18nc("@label:textbox", "API Token:")

            Layout.fillWidth: true
            text: cfg_openaiCompatibleToken
            onTextChanged: cfg_openaiCompatibleToken = text
            placeholderText: i18nc("@info:placeholder", "Enter your API token")
            echoMode: QQC2.TextField.Password
        }

        QQC2.Label {
            text: i18nc("@info", "Your API key/token for authentication")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: openaiCompatibleModelField

            Kirigami.FormData.label: i18nc("@label:textbox", "Model:")

            Layout.fillWidth: true
            text: cfg_openaiCompatibleModel
            onTextChanged: cfg_openaiCompatibleModel = text
            placeholderText: "gpt-4"
        }

        QQC2.Label {
            text: i18nc("@info", "The model name to use (e.g., gpt-4, gpt-3.5-turbo, deepseek-chat)")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.CheckBox {
            id: disableThinkingCheckBox

            Kirigami.FormData.label: i18nc("@label:checkbox", "Thinking Mode:")

            text: i18nc("@option:check", "Disable thinking/reasoning mode")
            checked: cfg_openaiCompatibleDisableThinking
            onCheckedChanged: cfg_openaiCompatibleDisableThinking = checked
        }

        QQC2.Label {
            text: i18nc("@info", "Disable thinking for faster responses (useful for non-reasoning models)")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
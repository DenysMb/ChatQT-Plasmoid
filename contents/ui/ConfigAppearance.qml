import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property string cfg_iconStyle: plasmoid.configuration.iconStyle
    property string cfg_provider: plasmoid.configuration.provider
    property string cfg_openclawUrl: plasmoid.configuration.openclawUrl
    property string cfg_openclawToken: plasmoid.configuration.openclawToken
    property string cfg_openaiCompatibleUrl: plasmoid.configuration.openaiCompatibleUrl
    property string cfg_openaiCompatibleToken: plasmoid.configuration.openaiCompatibleToken
    property string cfg_openaiCompatibleModel: plasmoid.configuration.openaiCompatibleModel
    property bool cfg_openaiCompatibleDisableThinking: plasmoid.configuration.openaiCompatibleDisableThinking

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: iconStyleComboBox

            Kirigami.FormData.label: i18nc("@title:group", "Icon style:")

            model: [
                { text: i18nc("@option:combobox", "Filled adaptive"), value: "filled-adaptive" },
                { text: i18nc("@option:combobox", "Outlined adaptive"), value: "outlined-adaptive" },
                { text: i18nc("@option:combobox", "Filled dark"), value: "filled-dark" },
                { text: i18nc("@option:combobox", "Filled light"), value: "filled-light" },
                { text: i18nc("@option:combobox", "Outlined dark"), value: "outlined-dark" },
                { text: i18nc("@option:combobox", "Outlined light"), value: "outlined-light" }
            ]

            textRole: "text"
            valueRole: "value"

            onCurrentValueChanged: {
                cfg_iconStyle = currentValue
            }

            Component.onCompleted: {
                currentIndex = indexOfValue(cfg_iconStyle)
            }
        }

        QQC2.ComboBox {
            id: providerComboBox

            Kirigami.FormData.label: i18nc("@title:group", "AI Provider:")

            model: [
                { text: i18nc("@option:combobox", "Ollama"), value: "ollama" },
                { text: i18nc("@option:combobox", "OpenClaw"), value: "openclaw" },
                { text: i18nc("@option:combobox", "OpenAI Compatible"), value: "openai-compatible" }
            ]

            textRole: "text"
            valueRole: "value"

            Component.onCompleted: {
                currentIndex = indexOfValue(cfg_provider || "ollama")
            }

            onActivated: {
                cfg_provider = currentValue
            }
        }

        QQC2.TextField {
            id: openclawUrlField

            visible: cfg_provider === "openclaw"
            Kirigami.FormData.label: i18nc("@title:group", "OpenClaw URL:")

            text: cfg_openclawUrl
            onTextChanged: cfg_openclawUrl = text

            placeholderText: "http://127.0.0.1:18789"
        }

        QQC2.TextField {
            id: openclawTokenField

            visible: cfg_provider === "openclaw"
            Kirigami.FormData.label: i18nc("@title:group", "OpenClaw Token:")

            text: cfg_openclawToken
            onTextChanged: cfg_openclawToken = text

            placeholderText: i18nc("@info:placeholder", "Enter your token")
            echoMode: QQC2.TextField.Password
        }

        QQC2.TextField {
            id: openaiCompatibleUrlField

            visible: cfg_provider === "openai-compatible"
            Kirigami.FormData.label: i18nc("@title:group", "API URL:")

            text: cfg_openaiCompatibleUrl
            onTextChanged: cfg_openaiCompatibleUrl = text

            placeholderText: "https://api.example.com/v1"
        }

        QQC2.TextField {
            id: openaiCompatibleTokenField

            visible: cfg_provider === "openai-compatible"
            Kirigami.FormData.label: i18nc("@title:group", "API Token:")

            text: cfg_openaiCompatibleToken
            onTextChanged: cfg_openaiCompatibleToken = text

            placeholderText: i18nc("@info:placeholder", "Enter your API token")
            echoMode: QQC2.TextField.Password
        }

        QQC2.TextField {
            id: openaiCompatibleModelField

            visible: cfg_provider === "openai-compatible"
            Kirigami.FormData.label: i18nc("@title:group", "Model:")

            text: cfg_openaiCompatibleModel
            onTextChanged: cfg_openaiCompatibleModel = text

            placeholderText: "gpt-4"
        }
    }
}
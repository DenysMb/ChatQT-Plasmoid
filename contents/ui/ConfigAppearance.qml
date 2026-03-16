import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.iconthemes as KIconThemes
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.kcmutils as KCM

import org.kde.plasma.core as PlasmaCore

KCM.SimpleKCM {
    property string cfg_icon: plasmoid.configuration.icon
    property string cfg_iconStyle: plasmoid.configuration.iconStyle
    property string cfg_provider: plasmoid.configuration.provider

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

            onCurrentValueChanged: {
                cfg_provider = currentValue
            }

            Component.onCompleted: {
                currentIndex = indexOfValue(cfg_provider || "ollama")
            }
        }
    }
}
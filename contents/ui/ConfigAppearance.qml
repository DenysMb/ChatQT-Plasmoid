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
    property bool cfg_pin: Plasmoid.configuration.pin
    property bool cfg_pinDefault: false

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: iconStyleComboBox

            Kirigami.FormData.label: i18nc("@label:listbox", "Icon style:")

            Layout.fillWidth: true

            model: [
                { text: i18nc("@item:inlistbox", "Filled adaptive"), value: "filled-adaptive" },
                { text: i18nc("@item:inlistbox", "Outlined adaptive"), value: "outlined-adaptive" },
                { text: i18nc("@item:inlistbox", "Filled dark"), value: "filled-dark" },
                { text: i18nc("@item:inlistbox", "Filled light"), value: "filled-light" },
                { text: i18nc("@item:inlistbox", "Outlined dark"), value: "outlined-dark" },
                { text: i18nc("@item:inlistbox", "Outlined light"), value: "outlined-light" }
            ]

            textRole: "text"
            valueRole: "value"

            Component.onCompleted: {
                currentIndex = indexOfValue(cfg_iconStyle || "filled-adaptive")
            }

            onActivated: function(index) {
                cfg_iconStyle = currentValue
            }
        }
    }
}
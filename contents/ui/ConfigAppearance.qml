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
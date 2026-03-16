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

    property string cfg_iconStyle: plasmoid.configuration.iconStyle

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Icon")
            Kirigami.FormData.isSection: true
        }

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

            Component.onCompleted: {
                currentIndex = indexOfValue(cfg_iconStyle || "filled-adaptive")
            }

            onActivated: {
                cfg_iconStyle = currentValue
            }
        }
    }
}
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

    property alias cfg_openclawUrl: openclawUrlField.text
    property alias cfg_openclawToken: openclawTokenField.text

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "OpenClaw Configuration")
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: openclawUrlField

            Kirigami.FormData.label: i18nc("@title:group", "URL:")
            text: plasmoid.configuration.openclawUrl || ""
            placeholderText: "http://127.0.0.1:18789"
        }

        QQC2.Label {
            text: i18nc("@info", "The URL of your OpenClaw instance")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        QQC2.TextField {
            id: openclawTokenField

            Kirigami.FormData.label: i18nc("@title:group", "Token:")
            text: plasmoid.configuration.openclawToken || ""
            placeholderText: i18nc("@info:placeholder", "Enter your token")
            echoMode: QQC2.TextField.Password
        }

        QQC2.Label {
            text: i18nc("@info", "Authentication token for OpenClaw")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
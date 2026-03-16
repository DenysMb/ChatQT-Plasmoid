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

    property string cfg_openclawUrl: Plasmoid.configuration.openclawUrl
    property string cfg_openclawToken: Plasmoid.configuration.openclawToken

    Kirigami.FormLayout {
        QQC2.TextField {
            id: openclawUrlField

            Kirigami.FormData.label: i18nc("@label:textbox", "URL:")

            Layout.fillWidth: true
            text: cfg_openclawUrl
            onTextChanged: cfg_openclawUrl = text
            placeholderText: "http://127.0.0.1:18789"
        }

        QQC2.Label {
            text: i18nc("@info", "The URL of your OpenClaw instance")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: openclawTokenField

            Kirigami.FormData.label: i18nc("@label:textbox", "Token:")

            Layout.fillWidth: true
            text: cfg_openclawToken
            onTextChanged: cfg_openclawToken = text
            placeholderText: i18nc("@info:placeholder", "Enter your token")
            echoMode: QQC2.TextField.Password
        }

        QQC2.Label {
            text: i18nc("@info", "Authentication token for OpenClaw")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
/*
 *  SPDX-FileCopyrightText: 2020 Sora Steenvoort <sora@dillbox.me>
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-system"
        source: "ConfigGeneral.qml"
    }

    ConfigCategory {
        name: i18n("OpenClaw")
        icon: "network-server"
        source: "ConfigOpenClaw.qml"
    }

    ConfigCategory {
        name: i18n("OpenAI Compatible")
        icon: "network-connect"
        source: "ConfigOpenAI.qml"
    }

    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
}
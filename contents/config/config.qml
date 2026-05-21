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
        name: i18n("Providers")
        icon: "preferences-system-network"
        source: "ConfigProviders.qml"
    }

    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }

    ConfigCategory {
        name: i18n("MCP & Skills")
        icon: "network-connect"
        source: "ConfigMCP.qml"
    }
}
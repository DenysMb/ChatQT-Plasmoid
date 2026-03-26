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
import "components" as COMPONENTS

KCM.SimpleKCM {
    id: root

    property string cfg_openaiCompatibleProviders: Plasmoid.configuration.openaiCompatibleProviders || "[]"

    ListModel {
        id: providersModel
    }

    Component.onCompleted: {
        loadProviders()
    }

    function loadProviders() {
        providersModel.clear()
        try {
            var providers = JSON.parse(cfg_openaiCompatibleProviders)
            console.log("Loaded providers:", providers.length)
            for (var i = 0; i < providers.length; i++) {
                console.log("Provider", i, ":", JSON.stringify(providers[i]))
                if (providers[i].enabled === undefined) {
                    providers[i].enabled = true
                }
                providersModel.append(providers[i])
            }
        } catch (e) {
            console.error("Failed to parse providers:", e)
        }
    }

    function saveProviders() {
        var providers = []
        for (var i = 0; i < providersModel.count; i++) {
            var item = providersModel.get(i)
            providers.push({
                displayName: item.displayName,
                url: item.url,
                token: item.token,
                model: item.model,
                enabled: item.enabled !== undefined ? item.enabled : true
            })
        }
        cfg_openaiCompatibleProviders = JSON.stringify(providers)
        console.log("Saved providers:", cfg_openaiCompatibleProviders)
    }

    function addProvider(provider) {
        if (provider === undefined) {
            provider = {
                displayName: i18nc("@info", "New Provider"),
                url: "",
                token: "",
                model: "",
                enabled: true
            }
        }
        if (provider.enabled === undefined) {
            provider.enabled = true
        }
        providersModel.append(provider)
        saveProviders()
    }

    function updateProvider(index, provider) {
        var existing = providersModel.get(index)
        if (existing.enabled !== undefined) {
            provider.enabled = existing.enabled
        }
        providersModel.set(index, provider)
        saveProviders()
    }

    function removeProvider(index) {
        providersModel.remove(index)
        saveProviders()
    }

    function toggleProviderEnabled(index) {
        var item = providersModel.get(index)
        providersModel.setProperty(index, "enabled", !item.enabled)
        saveProviders()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Configure multiple OpenAI-compatible API providers (OpenAI, DeepSeek, Groq, etc.). Add, edit, or remove providers using the buttons below.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            visible: providersModel.count > 0
            level: 2
            text: i18nc("@title:group", "Providers")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: providersModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: providersModel
                delegate: COMPONENTS.ProviderCard {
                    Layout.fillWidth: true
                    providerDisplayName: providersModel.get(index).displayName
                    providerUrl: providersModel.get(index).url
                    providerToken: providersModel.get(index).token
                    providerModel: providersModel.get(index).model
                    providerEnabled: providersModel.get(index).enabled !== undefined ? providersModel.get(index).enabled : true
                    onEditClicked: editSheet.openProvider(index)
                    onRemoveClicked: root.removeProvider(index)
                    onEnabledToggled: root.toggleProviderEnabled(index)
                }
            }
        }

        QQC2.Button {
            id: addButton
            text: i18nc("@action:button", "Add Provider")
            icon.name: "list-add-symbolic"
            Layout.fillWidth: true
            onClicked: editSheet.openNewProvider()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Kirigami.Dialog {
            id: editSheet
            title: i18nc("@title:window", "Edit Provider")

            property int editingIndex: -1

            function openNewProvider() {
                editingIndex = -1
                displayNameField.text = i18nc("@info", "New Provider")
                urlField.text = ""
                tokenField.text = ""
                modelField.text = ""
                editSheet.title = i18nc("@title:window", "Add Provider")
                editSheet.open()
            }

            function openProvider(index) {
                editingIndex = index
                var provider = providersModel.get(index)
                displayNameField.text = provider.displayName
                urlField.text = provider.url
                tokenField.text = provider.token
                modelField.text = provider.model
                editSheet.title = i18nc("@title:window", "Edit Provider")
                editSheet.open()
            }

            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

            onAccepted: {
                var provider = {
                    displayName: displayNameField.text,
                    url: urlField.text,
                    token: tokenField.text,
                    model: modelField.text
                }
                if (editingIndex >= 0) {
                    root.updateProvider(editingIndex, provider)
                } else {
                    root.addProvider(provider)
                }
            }

            Kirigami.FormLayout {
                QQC2.TextField {
                    id: displayNameField
                    Kirigami.FormData.label: i18nc("@label:textbox", "Display Name:")
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "e.g., DeepSeek, Groq, OpenAI")
                }

                QQC2.TextField {
                    id: urlField
                    Kirigami.FormData.label: i18nc("@label:textbox", "API URL:")
                    Layout.fillWidth: true
                    placeholderText: "https://api.openai.com/v1"
                }

                QQC2.TextField {
                    id: tokenField
                    Kirigami.FormData.label: i18nc("@label:textbox", "API Token:")
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Enter your API token")
                    echoMode: QQC2.TextField.Password
                }

                QQC2.TextField {
                    id: modelField
                    Kirigami.FormData.label: i18nc("@label:textbox", "Model:")
                    Layout.fillWidth: true
                    placeholderText: "gpt-4"
                }
            }
        }
    }
}

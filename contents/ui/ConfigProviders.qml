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
import "logic/ApiClient.js" as ApiClient

KCM.SimpleKCM {
    id: root

    property string cfg_iconStyle: Plasmoid.configuration.iconStyle
    property string cfg_iconStyleDefault: "filled-adaptive"
    property bool cfg_pin: Plasmoid.configuration.pin
    property bool cfg_pinDefault: false
    property string cfg_providers: Plasmoid.configuration.providers || "[]"

    ListModel {
        id: providersModel
    }

    Component.onCompleted: {
        loadProviders()
    }

    function loadProviders() {
        providersModel.clear()
        try {
            var providers = JSON.parse(cfg_providers)
            console.log("Loaded providers:", providers.length)
            for (var i = 0; i < providers.length; i++) {
                console.log("Provider", i, ":", JSON.stringify(providers[i]))
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
            var provider = {
                type: item.type,
                displayName: item.displayName || "",
                url: item.url || "",
                token: item.token || "",
                enabled: item.enabled !== false
            }
            if (item.type === "openai-compatible" && item.model) {
                provider.model = item.model
            }
            if (item.type === "ollama") {
                provider.url = item.url || "http://localhost:11434"
            }
            providers.push(provider)
        }
        cfg_providers = JSON.stringify(providers)
        console.log("Saved providers:", cfg_providers)
    }

    function addProvider(providerType) {
        var provider = {
            type: providerType || "ollama",
            displayName: getDefaultDisplayName(providerType || "ollama"),
            url: getDefaultUrl(providerType || "ollama"),
            token: "",
            enabled: true
        }
        if (providerType === "openai-compatible") {
            provider.model = ""
        }
        providersModel.append(provider)
        saveProviders()
    }

    function getDefaultDisplayName(type) {
        var names = {
            "ollama": i18nc("@info", "Ollama Local"),
            "openclaw": i18nc("@info", "OpenClaw Local"),
            "openai-compatible": i18nc("@info", "Custom API")
        }
        return names[type] || i18nc("@info", "New Provider")
    }

    function getDefaultUrl(type) {
        var urls = {
            "ollama": "http://localhost:11434",
            "openclaw": "http://127.0.0.1:18789",
            "openai-compatible": ""
        }
        return urls[type] || ""
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

    function getProviderIcon(type) {
        var icons = {
            "ollama": "drive-harddisk-symbolic",
            "openclaw": "network-server-symbolic",
            "openai-compatible": "cloud-symbolic"
        }
        return icons[type] || "applications-internet-symbolic"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Configure AI providers for the chat widget. Add multiple instances of Ollama, OpenClaw, or custom OpenAI-compatible APIs.")
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
                    providerDisplayName: providersModel.get(index).displayName || getDefaultDisplayName(providersModel.get(index).type)
                    providerUrl: providersModel.get(index).url || ""
                    providerToken: providersModel.get(index).token || ""
                    providerModel: providersModel.get(index).model || ""
                    providerType: providersModel.get(index).type
                    providerEnabled: providersModel.get(index).enabled !== false
                    onEditClicked: editSheet.openProvider(index)
                    onRemoveClicked: root.removeProvider(index)
                    onEnabledToggled: root.toggleProviderEnabled(index)
                }
            }
        }

        QQC2.Label {
            visible: providersModel.count === 0
            text: i18nc("@info", "No providers configured. Add one below.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
        }

        QQC2.Button {
            id: addButton
            text: i18nc("@action:button", "Add Provider")
            icon.name: "list-add-symbolic"
            Layout.fillWidth: true
            onClicked: addSheet.open()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Kirigami.Dialog {
            id: addSheet
            title: i18nc("@title:window", "Add Provider")
            width: parent.width - Kirigami.Units.largeSpacing * 4
            padding: Kirigami.Units.largeSpacing

            standardButtons: Kirigami.Dialog.Cancel

            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: [
                        { type: "ollama", name: "Ollama", icon: "drive-harddisk-symbolic", desc: "Local Ollama instance" },
                        { type: "openclaw", name: "OpenClaw", icon: "network-server-symbolic", desc: "OpenClaw server" },
                        { type: "openai-compatible", name: "OpenAI-Compatible", icon: "cloud-symbolic", desc: "Custom OpenAI-compatible API" }
                    ]

                    QQC2.Button {
                        Layout.fillWidth: true
                        text: modelData.name
                        icon.name: modelData.icon
                        onClicked: {
                            addSheet.close()
                            editSheet.openNewProvider(modelData.type)
                        }

                        QQC2.ToolTip.text: modelData.desc
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }
        }

        Kirigami.Dialog {
            id: editSheet
            title: i18nc("@title:window", "Edit Provider")
            padding: Kirigami.Units.largeSpacing
            width: Kirigami.Units.gridUnit * 32

            property int editingIndex: -1
            property string providerType: "ollama"
            property string testState: "idle"
            property int testModelCount: 0
            property int testErrorStatus: 0
            property string testErrorStatusText: ""
            property var testXhr: null

            Timer {
                id: testTimeoutTimer
                interval: 10000
                onTriggered: {
                    if (editSheet.testXhr) {
                        editSheet.testXhr.onreadystatechange = function() {};
                        editSheet.testXhr.abort();
                        editSheet.testXhr = null;
                    }
                    editSheet.testState = "error";
                    editSheet.testErrorStatus = 0;
                    editSheet.testErrorStatusText = "TIMEOUT";
                }
            }

            function resetTestState() {
                if (testXhr) {
                    testXhr.onreadystatechange = function() {};
                    testXhr.abort();
                    testXhr = null;
                }
                testTimeoutTimer.stop();
                testState = "idle";
                testModelCount = 0;
                testErrorStatus = 0;
                testErrorStatusText = "";
            }

            function openNewProvider(type) {
                resetTestState();
                editingIndex = -1
                providerType = type
                displayNameField.text = getDefaultDisplayName(type)
                urlField.text = getDefaultUrl(type)
                tokenField.text = ""
                modelField.text = ""
                editSheet.title = i18nc("@title:window", "Add Provider")
                editSheet.open()
            }

            function openProvider(index) {
                resetTestState();
                editingIndex = index
                var provider = providersModel.get(index)
                providerType = provider.type || "ollama"
                displayNameField.text = provider.displayName || ""
                urlField.text = provider.url || ""
                tokenField.text = provider.token || ""
                modelField.text = provider.model || ""
                editSheet.title = i18nc("@title:window", "Edit Provider")
                editSheet.open()
            }

            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

            onClosed: {
                resetTestState();
            }

            onAccepted: {
                var provider = {
                    type: providerType,
                    displayName: displayNameField.text,
                    url: urlField.text,
                    token: tokenField.text
                }
                if (providerType === "openai-compatible") {
                    provider.model = modelField.text
                }
                if (editingIndex >= 0) {
                    root.updateProvider(editingIndex, provider)
                } else {
                    providersModel.append(provider)
                    saveProviders()
                }
            }

            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18nc("@label:textbox", "Display Name:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: displayNameField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "e.g., OpenClaw Local")
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "API URL:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: urlField
                    Layout.fillWidth: true
                    placeholderText: editSheet.providerType === "ollama" ? "http://localhost:11434" :
                                     editSheet.providerType === "openclaw" ? "http://127.0.0.1:18789" :
                                     "https://api.example.com/v1"
                    onTextChanged: editSheet.resetTestState()
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "Token:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    visible: editSheet.providerType !== "ollama"
                }

                QQC2.TextField {
                    id: tokenField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Enter your API token")
                    echoMode: QQC2.TextField.Password
                    visible: editSheet.providerType !== "ollama"
                    onTextChanged: editSheet.resetTestState()
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "Model:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    visible: editSheet.providerType === "openai-compatible"
                }

                QQC2.TextField {
                    id: modelField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "e.g., gpt-4, claude-3-sonnet")
                    visible: editSheet.providerType === "openai-compatible"
                    onTextChanged: editSheet.resetTestState()
                }

                Kirigami.InlineMessage {
                    id: testResultMessage
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: true
                    type: {
                        if (editSheet.testState === "idle") return Kirigami.MessageType.Information;
                        if (editSheet.testState === "testing") return Kirigami.MessageType.Information;
                        if (editSheet.testState === "success") return Kirigami.MessageType.Positive;
                        if (editSheet.testState === "error") return Kirigami.MessageType.Error;
                        return Kirigami.MessageType.Information;
                    }
                    text: {
                        if (editSheet.testState === "idle") return i18nc("@info", "Connection has not been tested.");
                        if (editSheet.testState === "testing") return i18nc("@info", "Testing connection…");
                        if (editSheet.testState === "success") {
                            if (editSheet.testModelCount > 0) return i18nc("@info", "Connection successful. %1 model(s) available.").arg(editSheet.testModelCount);
                            return i18nc("@info", "Connection successful!");
                        }
                        if (editSheet.testErrorStatusText === "TIMEOUT") return i18nc("@info", "Connection timed out after 10 seconds.");
                        if (editSheet.testErrorStatusText === "NETWORK_ERROR") return i18nc("@info", "Could not reach the server. Check the URL and network connection.");
                        if (editSheet.testErrorStatusText === "UNAUTHORIZED") return i18nc("@info", "Authentication failed. Check your API token.");
                        if (editSheet.testErrorStatusText === "NOT_FOUND") return i18nc("@info", "Server not found at this URL. Check the API URL.");
                        if (editSheet.testErrorStatusText === "EMPTY_URL") return i18nc("@info", "Please enter an API URL before testing.");
                        if (editSheet.testErrorStatusText === "EMPTY_TOKEN") return i18nc("@info", "Please enter an API token before testing.");
                        if (editSheet.testErrorStatusText === "EMPTY_MODEL") return i18nc("@info", "Please enter a model name before testing.");
                        if (editSheet.testErrorStatus > 0) return i18nc("@info", "Server returned error %1: %2").arg(editSheet.testErrorStatus).arg(editSheet.testErrorStatusText);
                        return i18nc("@info", "Unknown connection error.");
                    }
                    actions: [
                        Kirigami.Action {
                            text: i18nc("@action:button", "Test Now")
                            visible: editSheet.testState === "idle"
                            onTriggered: editSheet.runTest()
                        }
                    ]
                }
            }

            function runTest() {
                resetTestState();

                if (!urlField.text.trim()) {
                    testState = "error";
                    testErrorStatusText = "EMPTY_URL";
                    return;
                }

                if (editSheet.providerType !== "ollama" && !tokenField.text.trim()) {
                    testState = "error";
                    testErrorStatusText = "EMPTY_TOKEN";
                    return;
                }

                if (editSheet.providerType === "openai-compatible" && !modelField.text.trim()) {
                    testState = "error";
                    testErrorStatusText = "EMPTY_MODEL";
                    return;
                }

                testState = "testing";

                var baseUrl = urlField.text.trim();
                var token = tokenField.text.trim();
                var model = modelField.text.trim();
                var extraHeaders = null;
                var includeV1 = false;

                if (editSheet.providerType === "openclaw") {
                    extraHeaders = { "x-openclaw-agent-id": "main" };
                    includeV1 = true;
                }

                testXhr = ApiClient.testConnection(
                    editSheet.providerType,
                    baseUrl,
                    token,
                    model,
                    extraHeaders,
                    includeV1,
                    function(result) {
                        testTimeoutTimer.stop();
                        testXhr = null;
                        testState = "success";
                        testModelCount = result.modelCount;
                    },
                    function(errorInfo) {
                        testTimeoutTimer.stop();
                        testXhr = null;
                        testState = "error";
                        testErrorStatus = errorInfo.status;
                        testErrorStatusText = errorInfo.statusText;
                    }
                );

                testTimeoutTimer.start();
            }


        }
    }
}

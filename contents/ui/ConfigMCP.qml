/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support
import QtCore
import "components" as COMPONENTS
import "logic/McpClient.js" as McpClient
import "logic/SkillManager.js" as SkillManager

KCM.SimpleKCM {
    id: root

    property string cfg_mcpServers: Plasmoid.configuration.mcpServers || "[]"
    property string cfg_skillFolders: Plasmoid.configuration.skillFolders || "[]"
    property string cfg_agentFilePath: Plasmoid.configuration.agentFilePath || ""

    property string _homeDir: {
        var homeUrl = StandardPaths.writableLocation(StandardPaths.HomeLocation);
        return homeUrl.toString().replace(/^file:\/\//, "");
    }

    ListModel { id: serversModel }
    ListModel { id: skillFoldersModel }
    ListModel { id: discoveredSkillsModel }

    function generateUuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.random() * 16 | 0
            var v = c === 'x' ? r : (r & 0x3 | 0x8)
            return v.toString(16)
        })
    }

    function expandPath(path) {
        return SkillManager.expandHomePath(path, _homeDir)
    }

    P5Support.DataSource {
        id: cmdSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"] || ""
            var exitCode = parseInt(data["exit code"] || "1")

            cmdSource.disconnectSource(sourceName)

            var item = root._execQueue.length > 0 ? root._execQueue.shift() : null
            root._execBusy = false

            if (item && item.callback) {
                item.callback(exitCode, stdout)
            }

            root._processQueue()
        }
    }

    property var _execQueue: []
    property bool _execBusy: false

    function runCommand(cmd, callback) {
        _execQueue.push({ cmd: cmd, callback: callback })
        _processQueue()
    }

    function _processQueue() {
        if (_execBusy || _execQueue.length === 0) return
        _execBusy = true
        var item = _execQueue[0]
        cmdSource.connectSource(item.cmd)
    }

    // --- MCP Servers ---

    function loadServers() {
        serversModel.clear()
        try {
            var servers = JSON.parse(cfg_mcpServers || "[]")
            for (var i = 0; i < servers.length; i++) {
                if (servers[i].enabled === undefined) servers[i].enabled = true
                if (!servers[i].id) servers[i].id = generateUuid()
                var state = McpClient.getServerState(servers[i].id)
                servers[i].connectionStatus = state ? (state.status || "disconnected") : "disconnected"
                servers[i].toolCount = state ? (state.toolCount || 0) : 0
                serversModel.append(servers[i])
            }
        } catch (e) {}
    }

    function saveServers() {
        var servers = []
        for (var i = 0; i < serversModel.count; i++) {
            var item = serversModel.get(i)
            servers.push({
                id: item.id, displayName: item.displayName,
                url: item.url || "", token: item.token || "",
                headers: item.headers || "",
                enabled: item.enabled !== undefined ? item.enabled : true
            })
        }
        cfg_mcpServers = JSON.stringify(servers)
    }

    function addServer(server) {
        if (server === undefined) {
            server = { id: generateUuid(), displayName: i18nc("@info", "New MCP Server"),
                        url: "", token: "", headers: "", enabled: true }
        }
        if (server.enabled === undefined) server.enabled = true
        if (!server.id) server.id = generateUuid()
        server.connectionStatus = "disconnected"
        server.toolCount = 0
        serversModel.append(server)
        saveServers()
    }

    function updateServer(index, server) {
        var existing = serversModel.get(index)
        if (existing.enabled !== undefined) server.enabled = existing.enabled
        server.connectionStatus = existing.connectionStatus || "disconnected"
        server.toolCount = existing.toolCount || 0
        serversModel.set(index, server)
        saveServers()
    }

    function removeServer(index) {
        var item = serversModel.get(index)
        if (item && item.id) McpClient.disconnectServer(item.id)
        serversModel.remove(index)
        saveServers()
    }

    function toggleServerEnabled(index) {
        var item = serversModel.get(index)
        serversModel.setProperty(index, "enabled", !item.enabled)
        saveServers()
    }

    function connectToServer(index) {
        var item = serversModel.get(index)
        if (!item || !item.url) return
        serversModel.setProperty(index, "connectionStatus", "connecting")
        var headers = {}
        if (item.token) headers["Authorization"] = "Bearer " + item.token
        if (item.headers) {
            try {
                var ch = JSON.parse(item.headers)
                var ks = Object.keys(ch)
                for (var i = 0; i < ks.length; i++) headers[ks[i]] = ch[ks[i]]
            } catch (e) {}
        }
        McpClient.initializeServer(item.url, headers,
            function(result) {
                McpClient.updateServerState(item.id, {
                    status: "connected", sessionId: result.sessionId,
                    serverInfo: result.serverInfo, capabilities: result.capabilities,
                    headers: headers, url: item.url.replace(/\/$/, ''), type: "remote"
                })
                McpClient.listTools(item.url, result.sessionId, headers,
                    function(tools) {
                        McpClient.updateServerState(item.id, { tools: tools, toolCount: tools.length })
                        serversModel.setProperty(index, "connectionStatus", "connected")
                        serversModel.setProperty(index, "toolCount", tools.length)
                    },
                    function() {
                        McpClient.updateServerState(item.id, { tools: [], toolCount: 0 })
                        serversModel.setProperty(index, "connectionStatus", "connected")
                        serversModel.setProperty(index, "toolCount", 0)
                    }
                )
            },
            function() {
                McpClient.updateServerState(item.id, { status: "error" })
                serversModel.setProperty(index, "connectionStatus", "error")
            }
        )
    }

    function disconnectFromServer(index) {
        var item = serversModel.get(index)
        if (!item || !item.id) return
        var state = McpClient.getServerState(item.id)
        if (state && state.url) {
            var xhr = new XMLHttpRequest()
            xhr.open("DELETE", state.url.replace(/\/$/, ''), true)
            if (state.sessionId) xhr.setRequestHeader("Mcp-Session-Id", state.sessionId)
            xhr.send()
        }
        McpClient.disconnectServer(item.id)
        serversModel.setProperty(index, "connectionStatus", "disconnected")
        serversModel.setProperty(index, "toolCount", 0)
    }

    // --- Skills ---

    function loadSkillFolders() {
        skillFoldersModel.clear()
        try {
            var folders = JSON.parse(cfg_skillFolders || "[]")
            for (var i = 0; i < folders.length; i++) {
                var val = typeof folders[i] === "string" ? folders[i] : (folders[i].folderPath || "")
                if (val) skillFoldersModel.append({"folderPath": val})
            }
        } catch (e) {}
        scanSkills()
    }

    function saveSkillFolders() {
        var folders = []
        for (var i = 0; i < skillFoldersModel.count; i++) {
            folders.push(skillFoldersModel.get(i).folderPath)
        }
        cfg_skillFolders = JSON.stringify(folders)
    }

    function addSkillFolder(path) {
        if (!path || path.trim() === "") return
        var clean = path.trim()
        for (var i = 0; i < skillFoldersModel.count; i++) {
            if (skillFoldersModel.get(i).folderPath === clean) return
        }
        skillFoldersModel.append({"folderPath": clean})
        saveSkillFolders()
        scanSkills()
    }

    function removeSkillFolder(index) {
        skillFoldersModel.remove(index)
        saveSkillFolders()
        scanSkills()
    }

    function scanSkills() {
        discoveredSkillsModel.clear()
        if (skillFoldersModel.count === 0) return

        var folders = []
        for (var i = 0; i < skillFoldersModel.count; i++) {
            folders.push(skillFoldersModel.get(i).folderPath)
        }

        var cmd = SkillManager.buildFullCommand(folders, "", _homeDir)

        runCommand(cmd, function(exitCode, stdout) {
            if (!stdout || stdout.length === 0) return

            var result = SkillManager.parseFullOutput(stdout)
            for (var i = 0; i < result.skills.length; i++) {
                var s = result.skills[i]
                discoveredSkillsModel.append({
                    "skillName": s.name,
                    "skillDescription": s.description,
                    "skillDirName": s.directoryName
                })
            }
        })
    }

    // --- Agent File ---

    function loadAgentPreview() {
        if (!cfg_agentFilePath || cfg_agentFilePath.trim() === "") {
            agentPreviewText.text = ""
            agentStatusLabel.text = i18nc("@info", "No agent file configured")
            agentStatusLabel.color = Kirigami.Theme.disabledTextColor
            return
        }

        agentStatusLabel.text = i18nc("@info", "Loading…")
        agentStatusLabel.color = Kirigami.Theme.neutralTextColor

        var expandedPath = expandPath(cfg_agentFilePath)
        var cmd = "/usr/bin/cat " + SkillManager.shellEscape(expandedPath)

        runCommand(cmd, function(exitCode, stdout) {
            if (stdout && stdout.length > 0) {
                agentPreviewText.text = stdout
                agentStatusLabel.text = i18nc("@info", "Loaded — %1 character(s)").arg(stdout.length)
                agentStatusLabel.color = Kirigami.Theme.positiveTextColor
            } else {
                agentPreviewText.text = ""
                agentStatusLabel.text = i18nc("@info", "File not found or could not be read")
                agentStatusLabel.color = Kirigami.Theme.negativeTextColor
            }
        })
    }

    Component.onCompleted: {
        loadServers()
        loadSkillFolders()
        loadAgentPreview()
    }

    // --- UI ---

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Configure MCP (Model Context Protocol) servers to give AI models access to external tools via remote HTTP connections.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            visible: serversModel.count > 0
            level: 2
            text: i18nc("@title:group", "MCP Servers")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: serversModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: serversModel
                delegate: COMPONENTS.McpCard {
                    Layout.fillWidth: true
                    serverDisplayName: model.displayName
                    serverUrl: model.url || ""
                    serverToken: model.token || ""
                    serverEnabled: model.enabled !== undefined ? model.enabled : true
                    serverStatus: model.connectionStatus || "disconnected"
                    serverToolCount: model.toolCount || 0
                    onEditClicked: editSheet.openServer(index)
                    onRemoveClicked: root.removeServer(index)
                    onEnabledToggled: root.toggleServerEnabled(index)
                    onConnectClicked: root.connectToServer(index)
                    onDisconnectClicked: root.disconnectFromServer(index)
                }
            }
        }

        QQC2.Button {
            text: i18nc("@action:button", "Add MCP Server")
            icon.name: "list-add-symbolic"
            Layout.fillWidth: true
            onClicked: editSheet.openNewServer()
        }

        Kirigami.Separator { Layout.fillWidth: true }

        QQC2.Label {
            text: i18nc("@info", "Skills are markdown files (SKILL.md) organized in subfolders. Add a parent folder to automatically discover all skills inside it.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            level: 2
            text: i18nc("@title:group", "Skill Folders")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: skillFoldersModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: skillFoldersModel
                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: "folder-symbolic"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                            color: Kirigami.Theme.disabledTextColor
                        }
                        QQC2.Label {
                            text: model.folderPath
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        QQC2.ToolButton {
                            icon.name: "entry-delete-symbolic"
                            display: QQC2.AbstractButton.IconOnly
                            text: i18nc("@action:button", "Remove")
                            onClicked: root.removeSkillFolder(index)
                            QQC2.ToolTip { text: parent.text; delay: Kirigami.Units.toolTipDelay }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                id: skillFolderField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "e.g., ~/.agents/skills")
            }
            QQC2.Button {
                icon.name: "list-add-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Add Skill Folder")
                enabled: skillFolderField.text.trim() !== ""
                onClicked: {
                    root.addSkillFolder(skillFolderField.text.trim())
                    skillFolderField.text = ""
                }
                QQC2.ToolTip { text: parent.text; delay: Kirigami.Units.toolTipDelay }
            }
        }

        QQC2.Button {
            text: i18nc("@action:button", "Rescan Skills")
            icon.name: "view-refresh-symbolic"
            Layout.fillWidth: true
            onClicked: root.scanSkills()
        }

        QQC2.ItemDelegate {
            id: skillsToggle
            Layout.fillWidth: true

            property bool expanded: false

            onClicked: expanded = !expanded

            contentItem: RowLayout {
                id: skillsHeaderRow
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: skillsToggle.expanded ? "arrow-down" : "arrow-right"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.disabledTextColor
                }

                Kirigami.Heading {
                    level: 3
                    text: i18nc("@title:group", "Discovered Skills")
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: discoveredSkillsModel.count > 0
                    radius: Kirigami.Units.smallSpacing
                    height: Kirigami.Units.gridUnit * 1.2
                    width: skillCountLabel.width + Kirigami.Units.smallSpacing * 2
                    color: Kirigami.Theme.positiveTextColor
                    QQC2.Label {
                        id: skillCountLabel
                        anchors.centerIn: parent
                        text: discoveredSkillsModel.count
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: Kirigami.Theme.backgroundColor
                    }
                }
            }
        }

        QQC2.Label {
            visible: discoveredSkillsModel.count === 0 && skillFoldersModel.count > 0
            text: i18nc("@info", "No skills found. Make sure subfolders contain SKILL.md files.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        ColumnLayout {
            id: skillsList
            Layout.fillWidth: true
            visible: skillsToggle.expanded && discoveredSkillsModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: discoveredSkillsModel
                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label {
                                text: model.skillName
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            QQC2.Label {
                                visible: model.skillDescription !== ""
                                text: model.skillDescription
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                        QQC2.Label {
                            text: model.skillDirName
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        QQC2.Label {
            text: i18nc("@info", "Select an agent instruction file (e.g., AGENTS.md or CLAUDE.md) that will be loaded into the chat context as persistent instructions.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            level: 2
            text: i18nc("@title:group", "Agent File")
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                id: agentPathField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "e.g., ~/.agents/AGENTS.md or ~/.claude/CLAUDE.md")
                text: cfg_agentFilePath
                onEditingFinished: {
                    cfg_agentFilePath = text
                    root.loadAgentPreview()
                }
            }
            QQC2.Button {
                visible: cfg_agentFilePath !== ""
                icon.name: "edit-delete-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Clear")
                onClicked: {
                    cfg_agentFilePath = ""
                    agentPathField.text = ""
                    agentPreviewText.text = ""
                    agentStatusLabel.text = i18nc("@info", "No agent file configured")
                    agentStatusLabel.color = Kirigami.Theme.disabledTextColor
                }
                QQC2.ToolTip { text: parent.text; delay: Kirigami.Units.toolTipDelay }
            }
        }

        QQC2.Label {
            id: agentStatusLabel
            text: i18nc("@info", "No agent file configured")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            visible: agentPreviewText.text !== ""
            clip: true
            QQC2.TextArea {
                id: agentPreviewText
                readOnly: true
                wrapMode: Text.WordWrap
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                background: null
            }
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        Kirigami.Dialog {
            id: editSheet
            parent: root
            title: i18nc("@title:window", "Edit MCP Server")
            padding: Kirigami.Units.largeSpacing
            width: Kirigami.Units.gridUnit * 32
            property int editingIndex: -1

            function openNewServer() {
                editingIndex = -1
                displayNameField.text = i18nc("@info", "New MCP Server")
                urlField.text = ""; tokenField.text = ""; headersField.text = ""
                editSheet.title = i18nc("@title:window", "Add MCP Server")
                editSheet.open()
            }

            function openServer(index) {
                editingIndex = index
                var server = serversModel.get(index)
                displayNameField.text = server.displayName
                urlField.text = server.url || ""
                tokenField.text = server.token || ""
                headersField.text = server.headers || ""
                editSheet.title = i18nc("@title:window", "Edit MCP Server")
                editSheet.open()
            }

            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
            onAccepted: {
                var server = { displayName: displayNameField.text, url: urlField.text,
                               token: tokenField.text, headers: headersField.text }
                if (editingIndex >= 0) root.updateServer(editingIndex, server)
                else root.addServer(server)
            }

            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                QQC2.Label { text: i18nc("@label:textbox", "Display Name:"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                QQC2.TextField { id: displayNameField; Layout.fillWidth: true; placeholderText: i18nc("@info:placeholder", "e.g., Exa Search, Filesystem") }
                QQC2.Label { text: i18nc("@label:textbox", "MCP Server URL:"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                QQC2.TextField { id: urlField; Layout.fillWidth: true; placeholderText: "https://mcp.exa.ai/mcp" }
                QQC2.Label { text: i18nc("@label:textbox", "API Token (optional):"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                QQC2.TextField { id: tokenField; Layout.fillWidth: true; placeholderText: i18nc("@info:placeholder", "Enter API token if required"); echoMode: QQC2.TextField.Password }
                QQC2.Label { text: i18nc("@label:textbox", "Custom Headers (JSON, optional):"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                QQC2.TextField { id: headersField; Layout.fillWidth: true; placeholderText: '{"x-api-key": "your-key"}' }
            }
        }
    }
}

/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import QtCore

import "components"
import "logic/ApiClient.js" as ApiClient
import "logic/SessionDB.js" as SessionDB
import "logic/McpClient.js" as McpClient
import "logic/SkillManager.js" as SkillManager

PlasmoidItem {
    id: root

    property string parentMessageId: ''
    property string currentModel: ''
    property var listModelController;
    property var scrollViewRef;
    property var promptArray: [];
    property var ollamaModels: [];
    property bool isLoading: false
    property bool hasLocalModel: false;
    property bool disableAutoScroll: false;
    property string currentProvider: Plasmoid.configuration.provider || "ollama"
    property bool thinkingEnabled: true
    property bool isStreaming: false
    property string lastSentMessage: ""
    property var activeXhr: null
    property string currentSessionId: ""
    property bool _sessionRestoreInProgress: false

    property var mcpFunctions: []
    property int mcpToolCallDepth: 0
    readonly property int mcpMaxToolCallDepth: 10
    property string _homeDir: ""
    property string cachedSystemMessage: ""
    property string _lastSkillFolders: ""
    property string _lastAgentFilePath: ""

    property var providers: {
        try {
            return JSON.parse(Plasmoid.configuration.providers || "[]");
        } catch (e) {
            return [];
        }
    }

    function isProviderConfigured() {
        var lastDash = currentProvider.lastIndexOf("-");
        if (lastDash < 1) return false;

        var type = currentProvider.substring(0, lastDash);
        var index = parseInt(currentProvider.substring(lastDash + 1));

        var provider = providers[index];
        if (!provider || provider.type !== type) return false;

        if (type === "ollama") {
            return hasLocalModel;
        } else if (type === "openclaw") {
            return provider.url && provider.token;
        } else if (type === "openai-compatible") {
            return provider.url && provider.token && provider.model;
        }
        return false;
    }

    function isProviderEnabled(providerId) {
        var lastDash = providerId.lastIndexOf("-");
        if (lastDash < 1) return false;

        var type = providerId.substring(0, lastDash);
        var index = parseInt(providerId.substring(lastDash + 1));

        var provider = providers[index];
        return provider && provider.type === type && provider.enabled !== false;
    }

    function getFirstAvailableProvider() {
        for (var i = 0; i < providers.length; i++) {
            var provider = providers[i];
            if (provider.enabled === false) continue;

            if (provider.type === "ollama" && hasLocalModel) {
                return "ollama-" + i;
            } else if (provider.type === "openclaw" && provider.url && provider.token) {
                return "openclaw-" + i;
            } else if (provider.type === "openai-compatible" && provider.url && provider.token && provider.model) {
                return "openai-compatible-" + i;
            }
        }
        return "ollama-0";
    }

    function getProviderNotConfiguredMessage() {
        var lastDash = currentProvider.lastIndexOf("-");
        if (lastDash < 1) return i18n("Provider not configured.");

        var type = currentProvider.substring(0, lastDash);
        var index = parseInt(currentProvider.substring(lastDash + 1));
        var provider = providers[index];

        if (type === "ollama") {
            return i18n("No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.");
        } else if (type === "openclaw") {
            return i18n("OpenClaw not configured.\nPlease set URL and Token in settings.");
        } else if (type === "openai-compatible") {
            var name = provider && provider.displayName ? provider.displayName : "OpenAI Compatible";
            return i18n("%1 not configured.\nPlease set URL, Token and Model in settings.", name);
        }
        return i18n("Provider not configured.");
    }

    function getProvider(index) {
        return providers[index];
    }

    function getProviderType() {
        var lastDash = currentProvider.lastIndexOf("-");
        return lastDash > 0 ? currentProvider.substring(0, lastDash) : "ollama";
    }

    function getProviderIndex() {
        var lastDash = currentProvider.lastIndexOf("-");
        return lastDash > 0 ? parseInt(currentProvider.substring(lastDash + 1)) : 0;
    }

    function gatherMcpFunctions() {
        var functions = [];
        try {
            var servers = JSON.parse(Plasmoid.configuration.mcpServers || "[]");
            for (var i = 0; i < servers.length; i++) {
                if (servers[i].enabled === false) continue;
                var state = McpClient.getServerState(servers[i].id);
                if (state && state.status === "connected" && state.tools && state.tools.length > 0) {
                    var converted = McpClient.mcpToolsToOpenAiFunctions(state.tools);
                    for (var j = 0; j < converted.length; j++) {
                        functions.push(converted[j]);
                    }
                }
            }
        } catch (e) {}
        return functions;
    }

    function hasConnectedMcpServers() {
        try {
            var servers = JSON.parse(Plasmoid.configuration.mcpServers || "[]");
            for (var i = 0; i < servers.length; i++) {
                if (servers[i].enabled === false) continue;
                var state = McpClient.getServerState(servers[i].id);
                if (state && state.status === "connected") {
                    return true;
                }
            }
        } catch (e) {}
        return false;
    }

    function expandPath(path) {
        return SkillManager.expandHomePath(path, _homeDir);
    }



    function loadSystemMessage() {
        var skillFolders = [];
        try {
            skillFolders = JSON.parse(Plasmoid.configuration.skillFolders || "[]");
        } catch (e) {}

        var agentPath = Plasmoid.configuration.agentFilePath || "";
        var cmd = SkillManager.buildFullCommand(skillFolders, agentPath, _homeDir);

        runCommand(cmd, function(exitCode, stdout) {
            if (stdout && stdout.length > 0) {
                var result = SkillManager.parseFullOutput(stdout);
                cachedSystemMessage = SkillManager.buildSystemMessage(result.skills, result.agentContent);
            } else {
                cachedSystemMessage = "";
            }
        });
    }

    function ensureSystemMessage() {
        if (promptArray.length > 0 && promptArray[0].role === "system") return;

        if (cachedSystemMessage !== "") {
            promptArray.unshift({"role": "system", "content": cachedSystemMessage});
        }
    }

    function handleStreaming(text, oldLength, listModel, thinkingText) {
        isStreaming = true;

        if (!disableAutoScroll && scrollViewRef && scrollViewRef.ScrollBar) {
            scrollViewRef.ScrollBar.vertical.position = 1 - scrollViewRef.ScrollBar.vertical.size;
        }

        if (listModel.count === oldLength) {
            listModel.append({
                "name": "Assistant",
                "number": text,
                "thinkingContent": thinkingText !== undefined ? thinkingText : ""
            });
        } else {
            listModel.setProperty(oldLength, "number", text);
            if (thinkingText !== undefined) {
                listModel.setProperty(oldLength, "thinkingContent", thinkingText);
            }
        }
    }

    function handleRequestComplete(oldLength, listModel, finalText, toolCalls) {
        if (activeXhr === null && mcpToolCallDepth === 0) return;

        var isOllamaError = getProviderType() === "ollama" && finalText && (
            finalText.indexOf("does not support") !== -1 ||
            finalText.indexOf("Ollama error") !== -1 ||
            finalText.startsWith("{\"error\"")
        );

        if (isOllamaError && listModel.count > oldLength) {
            listModel.setProperty(oldLength, "name", "Error");
            listModel.setProperty(oldLength, "thinkingContent", "");
            isLoading = false;
            activeXhr = null;
            isStreaming = false;
            mcpToolCallDepth = 0;
            autoSaveSession();
            return;
        }

        if (toolCalls && toolCalls.length > 0 && mcpToolCallDepth < mcpMaxToolCallDepth) {
            handleMcpToolCalls(oldLength, listModel, finalText, toolCalls);
            return;
        }

        if (toolCalls && toolCalls.length > 0 && mcpToolCallDepth >= mcpMaxToolCallDepth) {
            console.warn("MCP tool call depth limit reached (" + mcpMaxToolCallDepth + ")");
        }

        if (listModel.count > oldLength) {
            const lastValue = listModel.get(oldLength);
            promptArray.push({ "role": "assistant", "content": lastValue.number, "images": [] });
        }
        isLoading = false;
        activeXhr = null;
        isStreaming = false;
        mcpToolCallDepth = 0;
        autoSaveSession()
    }

    function handleMcpToolCalls(oldLength, listModel, finalText, toolCalls) {
        mcpToolCallDepth++;

        if (listModel.count === oldLength) {
            var displayText = finalText || "";
            if (displayText === "" && toolCalls.length > 0) {
                var toolNames = [];
                for (var t = 0; t < toolCalls.length; t++) {
                    toolNames.push(toolCalls[t].function.name);
                }
                displayText = i18n("Calling tools: %1", toolNames.join(", "));
            }

            listModel.append({
                "name": "Assistant",
                "number": displayText,
                "thinkingContent": ""
            });

            var assistantMsg = { "role": "assistant", "content": displayText };
            if (toolCalls.length > 0) {
                assistantMsg["tool_calls"] = toolCalls;
            }
            promptArray.push(assistantMsg);
        } else {
            if (finalText) {
                listModel.setProperty(oldLength, "number", finalText);
            }
            var existingAssistant = null;
            for (var p = promptArray.length - 1; p >= 0; p--) {
                if (promptArray[p].role === "assistant") {
                    existingAssistant = promptArray[p];
                    break;
                }
            }
            if (existingAssistant && toolCalls.length > 0) {
                existingAssistant["tool_calls"] = toolCalls;
            }
        }

        var pendingToolCalls = [];
        for (var i = 0; i < toolCalls.length; i++) {
            pendingToolCalls.push(toolCalls[i]);
        }

        executeNextMcpToolCall(pendingToolCalls, 0, oldLength, listModel);
    }

    function executeNextMcpToolCall(toolCalls, currentIndex, oldLength, listModel) {
        if (currentIndex >= toolCalls.length) {
            sendMcpFollowUpRequest(oldLength, listModel);
            return;
        }

        var toolCall = toolCalls[currentIndex];
        var funcName = toolCall.function.name;
        var funcArgs = {};
        try {
            funcArgs = JSON.parse(toolCall.function.arguments || "{}");
        } catch (e) {
            funcArgs = {};
        }

        var mcpToolName = McpClient.parseToolCallName(funcName);
        var isMcp = McpClient.isMcpToolCall(funcName);

        listModel.append({
            "name": "Tool",
            "number": i18n("Calling %1…").arg(funcName),
            "thinkingContent": ""
        });

        if (!isMcp) {
            var errorMsg = i18n("Tool %1 is not an MCP tool").arg(funcName);
            listModel.setProperty(listModel.count - 1, "number", errorMsg);
            promptArray.push({
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": errorMsg
            });
            executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel);
            return;
        }

        var servers = [];
        try {
            servers = JSON.parse(Plasmoid.configuration.mcpServers || "[]");
        } catch (e) {}

        var foundServer = null;
        var foundState = null;

        for (var s = 0; s < servers.length; s++) {
            if (servers[s].enabled === false) continue;
            var state = McpClient.getServerState(servers[s].id);
            if (state && state.tools) {
                for (var t = 0; t < state.tools.length; t++) {
                    if (state.tools[t].name === mcpToolName) {
                        foundServer = servers[s];
                        foundState = state;
                        break;
                    }
                }
                if (foundServer) break;
            }
        }

        if (!foundServer) {
            var errorMsg2 = i18n("MCP server not found for tool %1").arg(funcName);
            listModel.setProperty(listModel.count - 1, "number", errorMsg2);
            promptArray.push({
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": errorMsg2
            });
            executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel);
            return;
        }

        McpClient.callTool(
            foundState.url,
            foundState.sessionId,
            foundState.headers,
            mcpToolName,
            funcArgs,
            function(result) {
                var resultContent = result.content || "";
                if (result.isError) {
                    resultContent = i18n("Error: %1").arg(resultContent);
                }

                listModel.setProperty(listModel.count - 1, "number",
                    i18n("%1: %2").arg(funcName).arg(resultContent.substring(0, 500)));

                promptArray.push({
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": resultContent
                });

                executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel);
            },
            function(code, message) {
                var errorMsg3 = i18n("Tool %1 failed: %2").arg(funcName).arg(message);
                listModel.setProperty(listModel.count - 1, "number", errorMsg3);

                promptArray.push({
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": errorMsg3
                });

                executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel);
            }
        );
    }

    function sendMcpFollowUpRequest(oldLength, listModel) {
        var type = getProviderType();
        var index = getProviderIndex();
        var provider = getProvider(index);

        mcpFunctions = gatherMcpFunctions();

        if (type === "ollama") {
            var ollamaUrl = (provider && provider.url) ? provider.url : "http://localhost:11434";
            activeXhr = ApiClient.requestOllama(
                ollamaUrl,
                currentModel,
                promptArray,
                listModelController,
                handleStreaming,
                handleRequestComplete,
                thinkingEnabled,
                mcpFunctions.length > 0 ? mcpFunctions : undefined
            );
        } else if (type === "openclaw") {
            activeXhr = ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                "openclaw",
                promptArray,
                true,
                { "x-openclaw-agent-id": "main" },
                true,
                listModelController,
                handleStreaming,
                handleRequestComplete,
                undefined
            );
        } else if (type === "openai-compatible") {
            activeXhr = ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                provider.model,
                promptArray,
                thinkingEnabled,
                null,
                false,
                listModelController,
                handleStreaming,
                handleRequestComplete,
                mcpFunctions.length > 0 ? mcpFunctions : undefined
            );
        }
    }

    function cancelRequest() {
        if (!isLoading) return "";

        var wasStreamingBeforeAbort = isStreaming;

        ApiClient.abortActiveRequest();
        activeXhr = null;

        var restoreText = "";

        if (!wasStreamingBeforeAbort) {
            if (listModelController.count > 0) {
                listModelController.remove(listModelController.count - 1);
            }
            promptArray.pop();
            restoreText = lastSentMessage;
        }

        isLoading = false;
        isStreaming = false;
        mcpToolCallDepth = 0;
        autoSaveSession();
        return restoreText;
    }

    function stopRequest() {
        if (!isLoading) return;

        ApiClient.abortActiveRequest();
        activeXhr = null;

        if (listModelController.count > 0) {
            var lastIndex = listModelController.count - 1;
            var lastItem = listModelController.get(lastIndex);
            if (lastItem && lastItem.name === "Assistant") {
                promptArray.push({ "role": "assistant", "content": lastItem.number, "images": [] });
            }
        }

        isLoading = false;
        isStreaming = false;
        mcpToolCallDepth = 0;
        autoSaveSession();
    }

    function request(prompt) {
        isStreaming = false;
        lastSentMessage = prompt;

        ensureSystemMessage();

        listModelController.append({
            "name": "User",
            "number": prompt,
            "thinkingContent": ""
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;
        mcpToolCallDepth = 0;

        if (!disableAutoScroll && scrollViewRef && scrollViewRef.ScrollBar) {
            scrollViewRef.ScrollBar.vertical.position = 1;
        }

        mcpFunctions = gatherMcpFunctions();

        var type = getProviderType();
        var index = getProviderIndex();
        var provider = getProvider(index);

        var ollamaUrl = (provider && provider.url) ? provider.url : "http://localhost:11434";

        if (type === "ollama") {
            activeXhr = ApiClient.requestOllama(
                ollamaUrl,
                currentModel,
                promptArray,
                listModelController,
                handleStreaming,
                handleRequestComplete,
                thinkingEnabled,
                mcpFunctions.length > 0 ? mcpFunctions : undefined
            );
        } else if (type === "openclaw") {
            activeXhr = ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                "openclaw",
                promptArray,
                true,
                { "x-openclaw-agent-id": "main" },
                true,
                listModelController,
                handleStreaming,
                handleRequestComplete,
                undefined
            );
        } else if (type === "openai-compatible") {
            activeXhr = ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                provider.model,
                promptArray,
                thinkingEnabled,
                null,
                false,
                listModelController,
                handleStreaming,
                handleRequestComplete,
                mcpFunctions.length > 0 ? mcpFunctions : undefined
            );
        }
    }

    function getModels() {
        var ollamaUrl = "http://localhost:11434";
        for (var i = 0; i < providers.length; i++) {
            if (providers[i].type === "ollama" && providers[i].enabled !== false) {
                if (providers[i].url) ollamaUrl = providers[i].url;
                break;
            }
        }
        ApiClient.getOllamaModels(
            ollamaUrl,
            function(models) {
                if (models.length) {
                    hasLocalModel = true;
                    if (getProviderType() === "ollama" && !currentModel) {
                        currentModel = models[0];
                    }
                    ollamaModels = models.map(model => ({
                        text: ApiClient.parseTextToComboBox(model),
                        value: model
                    }));
                }
            },
            function(status, statusText) {
                console.error('Error fetching models:', status, statusText);
            }
        );
    }

    function initializeProvider() {
        if (!isProviderEnabled(currentProvider)) {
            currentProvider = getFirstAvailableProvider();
            Plasmoid.configuration.provider = currentProvider;
        }

        getModels();
    }

    function autoConnectMcpServers() {
        try {
            var servers = JSON.parse(Plasmoid.configuration.mcpServers || "[]");
            for (var i = 0; i < servers.length; i++) {
                if (servers[i].enabled === false) continue;
                if (!servers[i].url) continue;

                (function(server) {
                    var state = McpClient.getServerState(server.id);
                    if (state && state.status === "connected") return;

                    var headers = {};
                    if (server.token) {
                        headers["Authorization"] = "Bearer " + server.token;
                    }
                    if (server.headers) {
                        try {
                            var customHeaders = JSON.parse(server.headers);
                            var keys = Object.keys(customHeaders);
                            for (var k = 0; k < keys.length; k++) {
                                headers[keys[k]] = customHeaders[keys[k]];
                            }
                        } catch (e) {}
                    }

                    McpClient.initializeServer(
                        server.url,
                        headers,
                        function(result) {
                            McpClient.updateServerState(server.id, {
                                status: "connected",
                                sessionId: result.sessionId,
                                serverInfo: result.serverInfo,
                                capabilities: result.capabilities,
                                headers: headers,
                                url: server.url.replace(/\/$/, ''),
                                type: "remote"
                            });

                            McpClient.listTools(
                                server.url,
                                result.sessionId,
                                headers,
                                function(tools) {
                                    McpClient.updateServerState(server.id, {
                                        tools: tools,
                                        toolCount: tools.length
                                    });
                                    console.log("Auto-connected MCP:", server.displayName, "- tools:", tools.length);
                                },
                                function(code, message) {
                                    McpClient.updateServerState(server.id, {
                                        tools: [],
                                        toolCount: 0
                                    });
                                }
                            );
                        },
                        function(code, message) {
                            console.warn("Auto-connect MCP failed for", server.displayName, ":", message);
                        }
                    );
                })(servers[i]);
            }
        } catch (e) {
            console.warn("Auto-connect MCP error:", e);
        }
    }

    function getThinkingEnabledForCurrentProvider() {
        var provider = getProvider(getProviderIndex());
        return provider && provider.thinkingEnabled !== undefined ? provider.thinkingEnabled : true;
    }

    function _getProviderDisplayName(providerId) {
        var lastDash = providerId.lastIndexOf("-");
        if (lastDash < 1) return providerId;

        var type = providerId.substring(0, lastDash);
        var index = parseInt(providerId.substring(lastDash + 1));
        var provider = providers[index];

        if (!provider) return type;

        if (provider.displayName) return provider.displayName;
        if (type === "ollama") return "Ollama";
        if (type === "openclaw") return "OpenClaw";
        return type;
    }

    function _extractTitle() {
        if (!promptArray || promptArray.length === 0) {
            return i18n("New Chat");
        }
        for (var i = 0; i < promptArray.length; i++) {
            if (promptArray[i].role === "user" && promptArray[i].content) {
                var content = promptArray[i].content.trim();
                if (content.length > 60) {
                    return content.substring(0, 60) + "...";
                }
                return content;
            }
        }
        return i18n("Chat");
    }

    function _getDisplayMessages() {
        if (!listModelController) return [];
        var messages = [];
        for (var i = 0; i < listModelController.count; i++) {
            var item = listModelController.get(i);
            messages.push({"name": item.name, "number": item.number, "thinkingContent": item.thinkingContent || ""});
        }
        return messages;
    }

    function autoSaveSession() {
        if (_sessionRestoreInProgress) {
            console.log("autoSaveSession - skipped (restore in progress)");
            return;
        }
        if (promptArray.length === 0) {
            console.log("autoSaveSession - skipped (empty promptArray)");
            return;
        }
        var title = _extractTitle();
        console.log("autoSaveSession - saving with title:", title);
        currentSessionId = SessionDB.saveSession(
            currentSessionId,
            currentProvider,
            currentModel,
            promptArray,
            _getDisplayMessages(),
            title
        );
        console.log("autoSaveSession - saved with id:", currentSessionId);
    }

    function saveAndClearSession() {
        autoSaveSession();
        if (listModelController) listModelController.clear();
        promptArray = [];
        currentSessionId = "";
        parentMessageId = "";
        mcpToolCallDepth = 0;
    }

    function restoreSession(sessionId) {
        console.log("restoreSession called with id:", sessionId);
        autoSaveSession()
        _sessionRestoreInProgress = true;

        var session = SessionDB.loadSession(sessionId);
        console.log("restoreSession - loaded session:", session ? "found" : "not found");
        if (!session) {
            _sessionRestoreInProgress = false;
            return;
        }
        console.log("restoreSession - session has", session.display_messages.length, "display messages");

        listModelController.clear();

        currentSessionId = sessionId;
        currentProvider = session.provider;
        currentModel = session.model;
        promptArray = session.prompt_array;
        mcpToolCallDepth = 0;

        for (var i = 0; i < session.display_messages.length; i++) {
            var msg = session.display_messages[i];
            listModelController.append({"name": msg.name, "number": msg.number, "thinkingContent": msg.thinkingContent || ""});
        }

        _sessionRestoreInProgress = false;
        console.log("restoreSession - done");
    }

    function deleteSessionFromHistory(sessionId) {
        SessionDB.deleteSession(sessionId);
        if (sessionId === currentSessionId) {
            currentSessionId = "";
        }
    }

    Component.onCompleted: {
        var homeUrl = StandardPaths.writableLocation(StandardPaths.HomeLocation);
        _homeDir = homeUrl.toString().replace(/^file:\/\//, "");

        _lastSkillFolders = Plasmoid.configuration.skillFolders || "[]";
        _lastAgentFilePath = Plasmoid.configuration.agentFilePath || "";

        SessionDB.initDB();
        initializeProvider();
        autoConnectMcpServers();
        loadSystemMessage();
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

            root._processExecQueue()
        }
    }

    property var _execQueue: []
    property bool _execBusy: false

    function runCommand(cmd, callback) {
        _execQueue.push({ cmd: cmd, callback: callback })
        _processExecQueue()
    }

    function _processExecQueue() {
        if (_execBusy || _execQueue.length === 0) return
        _execBusy = true
        var item = _execQueue[0]
        cmdSource.connectSource(item.cmd)
    }

    Timer {
        id: configCheckTimer
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            var currentSkillFolders = Plasmoid.configuration.skillFolders || "[]"
            var currentAgentFilePath = Plasmoid.configuration.agentFilePath || ""

            if (currentSkillFolders !== root._lastSkillFolders || currentAgentFilePath !== root._lastAgentFilePath) {
                root._lastSkillFolders = currentSkillFolders
                root._lastAgentFilePath = currentAgentFilePath
                root.loadSystemMessage()
            }
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Keep Open")
            icon.name: "window-pin"
            checkable: true
            checked: Plasmoid.configuration.pin || false
            onTriggered: Plasmoid.configuration.pin = checked
        },
        PlasmaCore.Action {
            text: i18n("New chat")
            icon.name: "list-add-symbolic"
            onTriggered: {
                saveAndClearSession()
            }
        },
        PlasmaCore.Action {
            text: i18n("Disable auto scroll")
            icon.name: "transform-move-vertical"
            checkable: true
            checked: disableAutoScroll
            onTriggered: disableAutoScroll = !disableAutoScroll
        }
    ]

    compactRepresentation: CompactRepresentation {}

    fullRepresentation: ColumnLayout {
        property bool expanded: false

        Layout.preferredHeight: 600
        Layout.preferredWidth: 400
        Layout.fillWidth: true
        Layout.fillHeight: true

        Component.onCompleted: {
            expanded = Qt.binding(function() { return root.expanded; });
        }

        onExpandedChanged: {
            if (expanded) {
                focusTimer.start();
            }
        }

        Timer {
            id: focusTimer
            interval: 100
            onTriggered: {
                messageInput.textField.forceActiveFocus()
            }
        }

        Header {
            id: header

            isLoading: root.isLoading
            currentProvider: root.currentProvider
            currentModel: root.currentModel
            ollamaModels: root.ollamaModels
            providers: root.providers
            thinkingEnabled: root.thinkingEnabled
            listModelController: root.listModelController
            pinChecked: Plasmoid.configuration.pin || false

            onClearChatRequested: {
                saveAndClearSession()
            }

            onProviderSelected: function(provider, model) {
                autoSaveSession()
                root.currentProvider = provider;
                Plasmoid.configuration.provider = provider;
                if (getProviderType() === "ollama") {
                    root.currentModel = model;
                    if (root.ollamaModels.length === 0) {
                        root.getModels();
                    }
                }
                if (listModelController) listModelController.clear();
                promptArray = [];
                currentSessionId = "";
            }

            onPinToggled: function(checked) {
                Plasmoid.configuration.pin = checked;
                header.pinChecked = checked;
            }

            onThinkingToggled: function(enabled) {
                root.thinkingEnabled = enabled;
            }

            onSessionHistoryRequested: {
                sessionHistoryPopup.open()
            }
        }

        SessionHistoryPopup {
            id: sessionHistoryPopup
            parent: root.fullRepresentation
            currentSessionId: root.currentSessionId

            onRestoreSession: function(sessionId) {
                root.restoreSession(sessionId)
            }

            onDeleteSession: function(sessionId) {
                root.deleteSessionFromHistory(sessionId)
                sessionHistoryPopup.refreshSessions()
            }

            onNewChatRequested: {
                root.saveAndClearSession()
            }
        }

        ScrollView {
            id: scrollView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            clip: true

            Component.onCompleted: {
                scrollViewRef = scrollView;
            }

            ListView {
                id: listView
                spacing: Kirigami.Units.smallSpacing

                Layout.fillWidth: true
                Layout.fillHeight: true

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    visible: listView.count === 0
                    text: root.isProviderConfigured() ? i18n("I am waiting for your questions...") : root.getProviderNotConfiguredMessage()
                }

                model: ListModel {
                    id: listModel

                    Component.onCompleted: {
                        listModelController = listModel;
                    }
                }

                delegate: ChatMessage {
                    messageText: ApiClient.preprocessMarkdown(number)
                    senderName: name
                    thinkingText: model.thinkingContent || ""
                    isToolMessage: name === "Tool"
                    isErrorMessage: name === "Error"
                }
            }
        }

        MessageInput {
            id: messageInput

            Layout.fillWidth: true

            isProviderConfigured: root.isProviderConfigured()
            isLoading: root.isLoading
            isStreaming: root.isStreaming

            onCancelOrStop: {
                var restoreText = root.cancelRequest();
                if (restoreText) {
                    messageInput.textField.text = restoreText;
                }
            }

            onSendMessage: function(message) {
                if (message.trim()) {
                    root.request(message);
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true

            text: i18n("Refresh models list")
            visible: getProviderType() === "ollama" && !hasLocalModel

            onClicked: getModels()
        }
    }
}

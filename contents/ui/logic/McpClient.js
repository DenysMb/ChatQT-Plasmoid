/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _servers = {};
var _requestId = 1;

function getNextRequestId() {
    return _requestId++;
}

function resetRequestId() {
    _requestId = 1;
}

function createJsonRpcRequest(method, params) {
    return {
        jsonrpc: "2.0",
        id: getNextRequestId(),
        method: method,
        params: params || {}
    };
}

function createJsonRpcNotification(method, params) {
    return {
        jsonrpc: "2.0",
        method: method,
        params: params || {}
    };
}

function parseSseResponse(responseText) {
    var lines = responseText.split('\n');
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.startsWith('data: ')) {
            var dataStr = line.substring(6).trim();
            if (dataStr === '[DONE]') continue;
            try {
                return JSON.parse(dataStr);
            } catch (e) {
                continue;
            }
        }
    }
    try {
        return JSON.parse(responseText);
    } catch (e) {
        return null;
    }
}

function extractAllSseData(responseText) {
    var results = [];
    var lines = responseText.split('\n');
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.startsWith('data: ')) {
            var dataStr = line.substring(6).trim();
            if (dataStr === '[DONE]') continue;
            try {
                results.push(JSON.parse(dataStr));
            } catch (e) {
                continue;
            }
        }
    }
    if (results.length === 0) {
        try {
            results.push(JSON.parse(responseText));
        } catch (e) {}
    }
    return results;
}

function setupCommonHeaders(xhr, headers, sessionId) {
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Accept", "application/json, text/event-stream");
    if (sessionId) {
        xhr.setRequestHeader("Mcp-Session-Id", sessionId);
    }
    if (headers) {
        var keys = Object.keys(headers);
        for (var i = 0; i < keys.length; i++) {
            var lk = keys[i].toLowerCase();
            if (lk !== "content-type" && lk !== "accept" && lk !== "mcp-session-id") {
                xhr.setRequestHeader(keys[i], headers[i]);
            }
        }
    }
}

function initializeServer(serverUrl, headers, onSuccess, onError) {
    var url = serverUrl.replace(/\/$/, '');

    var initRequest = createJsonRpcRequest("initialize", {
        protocolVersion: "2025-03-26",
        capabilities: {
            roots: { listChanged: true },
            sampling: {}
        },
        clientInfo: {
            name: "ChatQT-Plasmoid",
            version: "1.0.0"
        }
    });

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    setupCommonHeaders(xhr, headers);

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 202) {
                try {
                    var response = parseSseResponse(xhr.responseText);
                    if (!response) {
                        if (typeof onError === "function") {
                            onError(-1, "Empty response from MCP server");
                        }
                        return;
                    }
                    if (response.result) {
                        var sessionId = xhr.getResponseHeader("Mcp-Session-Id") || "";
                        var serverUrl_ = url;

                        var notifyXhr = new XMLHttpRequest();
                        notifyXhr.open("POST", serverUrl_, true);
                        setupCommonHeaders(notifyXhr, headers, sessionId);
                        notifyXhr.send(JSON.stringify(createJsonRpcNotification("notifications/initialized", {})));

                        if (typeof onSuccess === "function") {
                            onSuccess({
                                serverInfo: response.result.serverInfo || {},
                                capabilities: response.result.capabilities || {},
                                sessionId: sessionId
                            });
                        }
                    } else if (response.error) {
                        if (typeof onError === "function") {
                            onError(response.error.code || -1, response.error.message || "MCP initialization error");
                        }
                    } else {
                        if (typeof onError === "function") {
                            onError(-1, "Unexpected MCP response format");
                        }
                    }
                } catch (e) {
                    if (typeof onError === "function") {
                        onError(-1, "Failed to parse MCP response: " + e.message);
                    }
                }
            } else {
                if (typeof onError === "function") {
                    var statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                    else if (xhr.status === 404) statusText = "NOT_FOUND";
                    else if (xhr.status === 405) statusText = "METHOD_NOT_ALLOWED";
                    onError(xhr.status, statusText);
                }
            }
        }
    };

    xhr.send(JSON.stringify(initRequest));
    return xhr;
}

function listTools(serverUrl, sessionId, headers, onSuccess, onError) {
    var url = serverUrl.replace(/\/$/, '');
    var request = createJsonRpcRequest("tools/list", {});

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    setupCommonHeaders(xhr, headers, sessionId);

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 202) {
                try {
                    var response = parseSseResponse(xhr.responseText);
                    if (!response) {
                        if (typeof onSuccess === "function") {
                            onSuccess([]);
                        }
                        return;
                    }
                    if (response.result && response.result.tools) {
                        if (typeof onSuccess === "function") {
                            onSuccess(response.result.tools);
                        }
                    } else if (response.error) {
                        if (typeof onError === "function") {
                            onError(response.error.code || -1, response.error.message || "MCP tools/list error");
                        }
                    } else {
                        if (typeof onSuccess === "function") {
                            onSuccess([]);
                        }
                    }
                } catch (e) {
                    if (typeof onError === "function") {
                        onError(-1, "Failed to parse tools response: " + e.message);
                    }
                }
            } else {
                if (typeof onError === "function") {
                    var statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    onError(xhr.status, statusText);
                }
            }
        }
    };

    xhr.send(JSON.stringify(request));
    return xhr;
}

function callTool(serverUrl, sessionId, headers, toolName, arguments, onSuccess, onError) {
    var url = serverUrl.replace(/\/$/, '');
    var request = createJsonRpcRequest("tools/call", {
        name: toolName,
        arguments: arguments || {}
    });

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    setupCommonHeaders(xhr, headers, sessionId);

    var accumulatedSseData = "";
    var parsedResult = null;

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            var responseText = xhr.responseText;
            if (responseText.length > accumulatedSseData.length) {
                var newChunk = responseText.substring(accumulatedSseData.length);
                accumulatedSseData = responseText;

                var sseResults = extractAllSseData(newChunk);
                for (var i = 0; i < sseResults.length; i++) {
                    if (sseResults[i].result) {
                        parsedResult = sseResults[i].result;
                    }
                }
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 202) {
                if (parsedResult) {
                    var resultText = "";
                    var isError = parsedResult.isError || false;

                    if (parsedResult.content) {
                        for (var i = 0; i < parsedResult.content.length; i++) {
                            var item = parsedResult.content[i];
                            if (item.type === "text") {
                                resultText += item.text;
                            } else if (item.type === "image") {
                                resultText += "[Image data]";
                            } else if (item.type === "audio") {
                                resultText += "[Audio data]";
                            } else if (item.type === "resource") {
                                resultText += item.resource.text || item.resource.uri || "[Resource]";
                            }
                        }
                    }

                    if (typeof onSuccess === "function") {
                        onSuccess({
                            content: resultText,
                            isError: isError
                        });
                    }
                } else {
                    try {
                        var response = parseSseResponse(xhr.responseText);
                        if (response && response.result) {
                            var res = response.result;
                            var txt = "";
                            var err = res.isError || false;
                            if (res.content) {
                                for (var j = 0; j < res.content.length; j++) {
                                    var c = res.content[j];
                                    if (c.type === "text") txt += c.text;
                                    else if (c.type === "image") txt += "[Image data]";
                                    else if (c.type === "audio") txt += "[Audio data]";
                                    else if (c.type === "resource") txt += (c.resource.text || c.resource.uri || "[Resource]");
                                }
                            }
                            if (typeof onSuccess === "function") {
                                onSuccess({ content: txt, isError: err });
                            }
                        } else if (response && response.error) {
                            if (typeof onError === "function") {
                                onError(response.error.code || -1, response.error.message || "MCP tool call error");
                            }
                        } else {
                            if (typeof onSuccess === "function") {
                                onSuccess({ content: "", isError: false });
                            }
                        }
                    } catch (e) {
                        if (typeof onError === "function") {
                            onError(-1, "Failed to parse tool call response: " + e.message);
                        }
                    }
                }
            } else {
                if (typeof onError === "function") {
                    var statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                    else if (xhr.status === 404) statusText = "NOT_FOUND";
                    onError(xhr.status, statusText);
                }
            }
        }
    };

    xhr.send(JSON.stringify(request));
    return xhr;
}

function disconnectServer(serverId) {
    if (_servers[serverId]) {
        delete _servers[serverId];
    }
}

function updateServerState(serverId, state) {
    _servers[serverId] = _servers[serverId] || {};
    Object.keys(state).forEach(function(key) {
        _servers[serverId][key] = state[key];
    });
}

function getServerState(serverId) {
    return _servers[serverId] || null;
}

function mcpToolsToOpenAiFunctions(tools) {
    var functions = [];
    if (!tools || !Array.isArray(tools)) return functions;

    for (var i = 0; i < tools.length; i++) {
        var tool = tools[i];
        if (!tool.name) continue;

        var func = {
            name: "mcp__" + tool.name,
            description: tool.description || "",
            parameters: tool.inputSchema || {
                type: "object",
                properties: {}
            }
        };

        functions.push(func);
    }

    return functions;
}

function parseToolCallName(functionName) {
    if (functionName && functionName.startsWith("mcp__")) {
        return functionName.substring(5);
    }
    return functionName;
}

function isMcpToolCall(functionName) {
    return functionName && functionName.startsWith("mcp__");
}

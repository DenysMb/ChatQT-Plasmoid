/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _activeXhr = null;

function normalizeUrl(url) {
    return url.replace(/\/$/, '');
}

function requestOllama(baseUrl, modelsComboboxCurrentValue, promptArray, listModel, onStreaming, onComplete, thinkingEnabled, mcpFunctions) {
    const oldLength = listModel.count;
    const url = normalizeUrl(baseUrl) + '/api/chat';

    let requestData = {
        "model": modelsComboboxCurrentValue,
        "keep_alive": "5m",
        "stream": true,
        "options": {},
        "messages": promptArray
    };

    if (thinkingEnabled === true) {
        requestData["think"] = true;
    }

    if (mcpFunctions && mcpFunctions.length > 0) {
        requestData["tools"] = mcpFunctions.map(function(f) {
            return {
                type: "function",
                function: {
                    name: f.name,
                    description: f.description,
                    parameters: f.parameters
                }
            };
        });
    }

    const data = JSON.stringify(requestData);

    _activeXhr = new XMLHttpRequest();
    var xhr = _activeXhr;

    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/json');

    let processedLength = 0;
    let accumulatedText = '';
    let accumulatedThinking = '';
    let toolCalls = {};
    let hasToolCalls = false;
    let errorDetected = false;

    xhr.onreadystatechange = function() {
        if (xhr.status === 0) return;

        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            const response = xhr.responseText;

            if (response.length > processedLength) {
                const newChunk = response.substring(processedLength);
                processedLength = response.length;

                const lines = newChunk.split('\n');
                let hasUpdate = false;

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;

                    try {
                        const parsedObject = JSON.parse(line);

                        if (parsedObject.error) {
                            errorDetected = true;
                            accumulatedText = parsedObject.error;
                            hasUpdate = true;
                            continue;
                        }

                        const content = parsedObject && parsedObject.message ? parsedObject.message.content : null;
                        const thinking = parsedObject && parsedObject.message ? parsedObject.message.thinking : null;
                        const msgToolCalls = parsedObject && parsedObject.message ? parsedObject.message.tool_calls : null;
                        const doneReason = parsedObject.done_reason;

                        if (content) {
                            accumulatedText += content;
                            hasUpdate = true;
                        }
                        if (thinking) {
                            accumulatedThinking += thinking;
                            hasUpdate = true;
                        }
                        if (msgToolCalls && msgToolCalls.length > 0) {
                            hasToolCalls = true;
                            for (let tc = 0; tc < msgToolCalls.length; tc++) {
                                const tcItem = msgToolCalls[tc];
                                const tcIndex = tc;
                                if (!toolCalls[tcIndex]) {
                                    toolCalls[tcIndex] = {
                                        id: tcItem.id || ("ollama_tc_" + tcIndex),
                                        type: "function",
                                        function: {
                                            name: "",
                                            arguments: ""
                                        }
                                    };
                                }
                                if (tcItem.id) {
                                    toolCalls[tcIndex].id = tcItem.id;
                                }
                                if (tcItem.function) {
                                    if (tcItem.function.name) {
                                        toolCalls[tcIndex].function.name = tcItem.function.name;
                                    }
                                    if (tcItem.function.arguments) {
                                        if (typeof tcItem.function.arguments === 'string') {
                                            toolCalls[tcIndex].function.arguments += tcItem.function.arguments;
                                        } else {
                                            toolCalls[tcIndex].function.arguments += JSON.stringify(tcItem.function.arguments);
                                        }
                                    }
                                }
                            }
                        }
                        if (doneReason === 'tool_calls') {
                            hasToolCalls = true;
                        }
                    } catch (e) {
                        // Skip invalid JSON
                    }
                }

                if (hasUpdate && typeof onStreaming === 'function') {
                    onStreaming(accumulatedText, oldLength, listModel, accumulatedThinking);
                }
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 0) return;

            if (typeof onComplete === 'function') {
                if (xhr.status !== 200 && !errorDetected && accumulatedText === '') {
                    accumulatedText = 'Ollama error: HTTP ' + xhr.status;
                    if (xhr.responseText) {
                        try {
                            const errObj = JSON.parse(xhr.responseText);
                            if (errObj.error) {
                                accumulatedText = errObj.error;
                            }
                        } catch (e) {}
                    }
                }
                let finalToolCalls = [];
                if (hasToolCalls && !errorDetected) {
                    let tcKeys = Object.keys(toolCalls);
                    for (let k = 0; k < tcKeys.length; k++) {
                        finalToolCalls.push(toolCalls[tcKeys[k]]);
                    }
                }
                onComplete(oldLength, listModel, accumulatedText, finalToolCalls);
            }
        }
    };

    xhr.send(data);
    return _activeXhr;
}

function requestOpenAICompatible(baseUrl, token, model, promptArray, thinkingEnabled, extraHeaders, includeV1, listModel, onStreaming, onComplete, mcpFunctions) {
    const oldLength = listModel.count;
    let url = normalizeUrl(baseUrl);
    if (includeV1) {
        url += '/v1';
    }
    url += '/chat/completions';

    let requestData = {
        "model": model,
        "messages": promptArray,
        "stream": true
    };

    if (!thinkingEnabled) {
        requestData["chat_template_kwargs"] = {"enable_thinking": false};
    }

    if (mcpFunctions && mcpFunctions.length > 0) {
        requestData["tools"] = mcpFunctions.map(function(f) {
            return {
                type: "function",
                function: {
                    name: f.name,
                    description: f.description,
                    parameters: f.parameters
                }
            };
        });
    }

    const data = JSON.stringify(requestData);

    _activeXhr = new XMLHttpRequest();
    var xhr = _activeXhr;

    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('Authorization', 'Bearer ' + token);

    if (extraHeaders) {
        for (const [key, value] of Object.entries(extraHeaders)) {
            xhr.setRequestHeader(key, value);
        }
    }

    let text = '';
    let thinkingText = '';
    let processedLength = 0;
    let toolCalls = {};
    let hasToolCalls = false;

    xhr.onreadystatechange = function() {
        if (xhr.status === 0) return;

        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            const response = xhr.responseText;

            if (response.length > processedLength) {
                const newChunk = response.substring(processedLength);
                processedLength = response.length;

                const lines = newChunk.split('\n');

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();

                    if (line.startsWith('data: ')) {
                        const dataStr = line.substring(6);

                        if (dataStr === '[DONE]') {
                            continue;
                        }

                        try {
                            const parsed = JSON.parse(dataStr);
                            const choices = parsed.choices;
                            if (choices && choices.length > 0) {
                                const delta = choices[0].delta;
                                const finishReason = choices[0].finish_reason;
                                if (delta) {
                                    let hasUpdate = false;

                                    if (delta.reasoning_content) {
                                        thinkingText += delta.reasoning_content;
                                        hasUpdate = true;
                                    }

                                    if (delta.reasoning) {
                                        thinkingText += delta.reasoning;
                                        hasUpdate = true;
                                    }

                                    if (delta.content) {
                                        text += delta.content;
                                        hasUpdate = true;
                                    }

                                    if (delta.tool_calls) {
                                        hasToolCalls = true;
                                        for (var tc = 0; tc < delta.tool_calls.length; tc++) {
                                            var toolCall = delta.tool_calls[tc];
                                            var tcIndex = toolCall.index !== undefined ? toolCall.index : tc;
                                            if (!toolCalls[tcIndex]) {
                                                toolCalls[tcIndex] = {
                                                    id: toolCall.id || "",
                                                    type: "function",
                                                    function: {
                                                        name: "",
                                                        arguments: ""
                                                    }
                                                };
                                            }
                                            if (toolCall.id) {
                                                toolCalls[tcIndex].id = toolCall.id;
                                            }
                                            if (toolCall.function) {
                                                if (toolCall.function.name) {
                                                    toolCalls[tcIndex].function.name += toolCall.function.name;
                                                }
                                                if (toolCall.function.arguments) {
                                                    toolCalls[tcIndex].function.arguments += toolCall.function.arguments;
                                                }
                                            }
                                        }
                                    }

                                    if (hasUpdate && typeof onStreaming === 'function') {
                                        onStreaming(text, oldLength, listModel, thinkingText);
                                    }
                                }

                                if (finishReason === 'tool_calls') {
                                    hasToolCalls = true;
                                }
                            }
                        } catch (e) {
                            // Skip invalid JSON
                        }
                    }
                }
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status !== 0 && typeof onComplete === 'function') {
                var finalToolCalls = [];
                if (hasToolCalls) {
                    var tcKeys = Object.keys(toolCalls);
                    for (var k = 0; k < tcKeys.length; k++) {
                        finalToolCalls.push(toolCalls[tcKeys[k]]);
                    }
                }
                onComplete(oldLength, listModel, text, finalToolCalls);
            }
        }
    };

    xhr.send(data);
    return _activeXhr;
}

function abortActiveRequest() {
    console.log("abortActiveRequest called — _activeXhr:", _activeXhr);
    if (_activeXhr) {
        _activeXhr.onreadystatechange = function() {};
        _activeXhr.onload = function() {};
        _activeXhr.abort();
        _activeXhr = null;
        console.log("abortActiveRequest — aborted and nulled");
        return true;
    }
    console.log("abortActiveRequest — no active XHR to abort");
    return false;
}

function getOllamaModels(baseUrl, onSuccess, onError) {
    const url = normalizeUrl(baseUrl) + '/api/tags';

    let xhr = new XMLHttpRequest();

    xhr.open('GET', url);
    xhr.setRequestHeader('Content-Type', 'application/json');

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var objects = response.models || [];
                    var models = objects.map(function(object) { return object.model; });
                    if (typeof onSuccess === 'function') {
                        onSuccess(models);
                    }
                } catch (e) {
                    if (typeof onError === 'function') {
                        onError(xhr.status, "PARSE_ERROR");
                    }
                }
            } else {
                if (typeof onError === 'function') {
                    onError(xhr.status, xhr.statusText);
                }
            }
        }
    };

    xhr.send();
}

function testConnection(providerType, baseUrl, token, model, extraHeaders, includeV1, onSuccess, onError) {
    var cleanUrl = normalizeUrl(baseUrl);

    if (providerType === "ollama") {
        var url = cleanUrl + "/api/tags";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var modelCount = response.models ? response.models.length : 0;
                        if (typeof onSuccess === "function") {
                            onSuccess({ modelCount: modelCount });
                        }
                    } catch (e) {
                        if (typeof onSuccess === "function") {
                            onSuccess({ modelCount: 0 });
                        }
                    }
                } else {
                    if (typeof onError === "function") {
                        var statusText = xhr.statusText || "UNKNOWN";
                        if (xhr.status === 0) statusText = "NETWORK_ERROR";
                        else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                        else if (xhr.status === 404) statusText = "NOT_FOUND";
                        onError({ status: xhr.status, statusText: statusText });
                    }
                }
            }
        };

        xhr.send();
        return xhr;
    }

    var url = cleanUrl;
    if (includeV1 && !cleanUrl.endsWith("/v1")) {
        url = cleanUrl + "/v1";
    }
    url += "/chat/completions";

    var data = JSON.stringify({
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1
    });

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    if (token) {
        xhr.setRequestHeader("Authorization", "Bearer " + token);
    }

    if (extraHeaders) {
        var keys = Object.keys(extraHeaders);
        for (var i = 0; i < keys.length; i++) {
            xhr.setRequestHeader(keys[i], extraHeaders[keys[i]]);
        }
    }

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                if (typeof onSuccess === "function") {
                    onSuccess({ modelCount: 0 });
                }
            } else {
                if (typeof onError === "function") {
                    var statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                    else if (xhr.status === 404) statusText = "NOT_FOUND";
                    onError({ status: xhr.status, statusText: statusText });
                }
            }
        }
    };

    xhr.send(data);
    return xhr;
}

function preprocessMarkdown(text) {
    return text
        .replace(/^#{1,6}\s+(.+)$/gm, '**$1**')
        .replace(/\*\*\*([^*]+)\*\*\*/g, '**$1**')
        .replace(/___([^_]+)___/g, '*$1*');
}

function parseTextToComboBox(text) {
    return text
        .replace(/-/g, ' ')
        .replace(/:(.+)/, ' ($1)')
        .split(' ')
        .map(word => {
            if (word.startsWith('(')) {
                return word.charAt(0) + word.charAt(1).toUpperCase() + word.slice(2);
            }
            return word.charAt(0).toUpperCase() + word.slice(1);
        })
        .join(' ');
}
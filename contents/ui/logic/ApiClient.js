/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _activeXhr = null;

function requestOllama(modelsComboboxCurrentValue, promptArray, listModel, onStreaming, onComplete) {
    const oldLength = listModel.count;
    const url = 'http://127.0.0.1:11434/api/chat';
    const data = JSON.stringify({
        "model": modelsComboboxCurrentValue,
        "keep_alive": "5m",
        "options": {},
        "messages": promptArray
    });

    _activeXhr = new XMLHttpRequest();
    var xhr = _activeXhr;

    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.onreadystatechange = function() {
        if (xhr.status === 0) return;

        const objects = xhr.responseText.split('\n');
        let text = '';

        objects.forEach((object, index) => {
            try {
                const parsedObject = JSON.parse(object);
                text = text + (parsedObject?.message?.content || '');

                if (index === 0) {
                    text = text.trim();
                }

                if (typeof onStreaming === 'function') {
                    onStreaming(text, oldLength, listModel);
                }
            } catch (e) {
                // Skip invalid JSON
            }
        });
    };

    xhr.onload = function() {
        if (xhr.status === 0) return;

        if (typeof onComplete === 'function') {
            onComplete(oldLength, listModel);
        }
    };

    xhr.send(data);
    return _activeXhr;
}

function requestOpenAICompatible(baseUrl, token, model, promptArray, thinkingEnabled, extraHeaders, includeV1, listModel, onStreaming, onComplete) {
    const oldLength = listModel.count;
    let url = baseUrl.replace(/\/$/, '');
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
    let processedLength = 0;

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
                                if (delta && delta.content) {
                                    text += delta.content;

                                    if (typeof onStreaming === 'function') {
                                        onStreaming(text, oldLength, listModel);
                                    }
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
                onComplete(oldLength, listModel);
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

function getOllamaModels(onSuccess, onError) {
    const url = 'http://127.0.0.1:11434/api/tags';

    let xhr = new XMLHttpRequest();

    xhr.open('GET', url);
    xhr.setRequestHeader('Content-Type', 'application/json');

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                const objects = JSON.parse(xhr.responseText).models;
                const models = objects.map(object => object.model);
                if (typeof onSuccess === 'function') {
                    onSuccess(models);
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
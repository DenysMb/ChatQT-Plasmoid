/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

.import QtQuick.LocalStorage 2.0 as LS

var _db = null;

function _getDB() {
    if (_db !== null) return _db;

    _db = LS.LocalStorage.openDatabaseSync("ChatQTSessions", "1.0", "ChatQT Session Storage", 1000000);

    _db.transaction(function(tx) {
        tx.executeSql('CREATE TABLE IF NOT EXISTS sessions ('
            + 'id TEXT PRIMARY KEY, '
            + 'provider TEXT NOT NULL DEFAULT \'\', '
            + 'model TEXT NOT NULL DEFAULT \'\', '
            + 'created_at INTEGER NOT NULL, '
            + 'updated_at INTEGER NOT NULL, '
            + 'prompt_array TEXT NOT NULL DEFAULT \'[]\', '
            + 'display_messages TEXT NOT NULL DEFAULT \'[]\', '
            + 'title TEXT NOT NULL DEFAULT \'\')');
    });

    return _db;
}

function _generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
}

function initDB() {
    _getDB();
}

function saveSession(id, provider, model, promptArray, displayMessages, title) {
    var db = _getDB();
    var now = Date.now();
    var sessionId = id || _generateId();
    var isNew = !id;
    var promptStr = JSON.stringify(promptArray);
    var displayStr = JSON.stringify(displayMessages);

    db.transaction(function(tx) {
        if (isNew) {
            tx.executeSql(
                'INSERT INTO sessions (id, provider, model, created_at, updated_at, prompt_array, display_messages, title) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                [sessionId, provider, model, now, now, promptStr, displayStr, title]
            );
        } else {
            var rs = tx.executeSql('SELECT id FROM sessions WHERE id = ?', [sessionId]);
            if (rs.rows.length > 0) {
                tx.executeSql(
                    'UPDATE sessions SET provider = ?, model = ?, updated_at = ?, prompt_array = ?, display_messages = ?, title = ? WHERE id = ?',
                    [provider, model, now, promptStr, displayStr, title, sessionId]
                );
            } else {
                tx.executeSql(
                    'INSERT INTO sessions (id, provider, model, created_at, updated_at, prompt_array, display_messages, title) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    [sessionId, provider, model, now, now, promptStr, displayStr, title]
                );
            }
        }
    });

    return sessionId;
}

function loadSession(id) {
    var db = _getDB();
    var result = null;

    db.readTransaction(function(tx) {
        var rs = tx.executeSql('SELECT * FROM sessions WHERE id = ?', [id]);
        if (rs.rows.length > 0) {
            var row = rs.rows.item(0);
            result = {
                id: row.id,
                provider: row.provider,
                model: row.model,
                created_at: row.created_at,
                updated_at: row.updated_at,
                prompt_array: JSON.parse(row.prompt_array),
                display_messages: JSON.parse(row.display_messages),
                title: row.title
            };
        }
    });

    return result;
}

function listSessions() {
    var db = _getDB();
    var sessions = [];

    db.readTransaction(function(tx) {
        var rs = tx.executeSql('SELECT id, provider, model, created_at, updated_at, title FROM sessions ORDER BY updated_at DESC');
        for (var i = 0; i < rs.rows.length; i++) {
            sessions.push(rs.rows.item(i));
        }
    });

    return sessions;
}

function deleteSession(id) {
    var db = _getDB();
    db.transaction(function(tx) {
        tx.executeSql('DELETE FROM sessions WHERE id = ?', [id]);
    });
}

function deleteAllSessions() {
    var db = _getDB();
    db.transaction(function(tx) {
        tx.executeSql('DELETE FROM sessions');
    });
}

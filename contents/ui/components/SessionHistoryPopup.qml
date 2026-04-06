/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../logic/SessionDB.js" as SessionDB

Popup {
    id: root

    property string currentSessionId: ""

    signal restoreSession(string sessionId)
    signal deleteSession(string sessionId)
    signal newChatRequested

    width: Math.min(parent.width - 20, 380)
    height: Math.min(parent.height - 40, 450)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0

    onAboutToShow: refreshSessions()

    function refreshSessions() {
        sessionListModel.clear();
        var sessions = SessionDB.listSessions();
        console.log("SessionHistoryPopup - loaded sessions:", sessions.length);
        for (var i = 0; i < sessions.length; i++) {
            console.log("Session", i, "id:", sessions[i].id, "title:", sessions[i].title);
            sessionListModel.append({
                "session_id": sessions[i].id,
                "session_title": sessions[i].title,
                "session_provider": sessions[i].provider,
                "session_model": sessions[i].model,
                "session_created_at": sessions[i].created_at,
                "session_updated_at": sessions[i].updated_at
            });
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: i18n("Chat History")
                level: 2
                Layout.fillWidth: true
            }

            PlasmaComponents.ToolButton {
                icon.name: "list-add-symbolic"
                text: i18n("New Chat")
                display: PlasmaComponents.AbstractButton.IconOnly

                onClicked: {
                    root.newChatRequested();
                    root.close();
                }

                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ListView {
            id: sessionListView

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            model: ListModel {
                id: sessionListModel
            }

            delegate: PlasmaComponents.ItemDelegate {
            width: sessionListView.width
            property string delegateSessionId: session_id
            highlighted: delegateSessionId === root.currentSessionId

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: session_title || i18n("Untitled session")
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        font.bold: true
                    }

                    Label {
                        text: Qt.formatDateTime(new Date(session_updated_at), "dd MMM yyyy, hh:mm")
                        color: Kirigami.Theme.disabledTextColor
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-delete-symbolic"
                    display: PlasmaComponents.AbstractButton.IconOnly

                    onClicked: {
                        root.deleteSession(delegateSessionId);
                        root.refreshSessions();
                    }

                    PlasmaComponents.ToolTip.text: i18n("Delete")
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents.ToolTip.visible: hovered
                }
            }

            onClicked: {
                console.log("delegate clicked - delegateSessionId:", delegateSessionId);
                root.restoreSession(delegateSessionId);
                root.close();
            }
        }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - (Kirigami.Units.largeSpacing * 4)
                visible: sessionListView.count === 0
                text: i18n("No saved sessions")
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: sessionListView.count > 0
        }

        PlasmaComponents.ToolButton {
            Layout.fillWidth: true
            visible: sessionListView.count > 0
            icon.name: "edit-clear-list"
            text: i18n("Clear All")

            onClicked: {
                SessionDB.deleteAllSessions();
                root.refreshSessions();
            }
        }
    }
}

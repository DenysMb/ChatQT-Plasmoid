/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

PlasmaExtras.PlasmoidHeading {
    id: root

    signal clearChatRequested
    signal modelSelected(string modelValue)

    property bool isProviderConfigured: false
    property bool isLoading: false
    property string currentProvider: "ollama"
    property bool hasLocalModel: false
    property var modelsArray: []
    property var modelsComboboxCurrentValue: ""
    property bool thinkingEnabled: true
    property var listModelController: null
    property string openaiCompatibleModelName: ""

    width: parent.width

    contentItem: RowLayout {
        visible: root.isProviderConfigured
        Layout.fillWidth: true

        PlasmaComponents.ToolButton {
            icon.name: "edit-clear-history-symbolic"
            text: i18n("Clear chat")
            display: PlasmaComponents.AbstractButton.IconOnly
            enabled: root.isProviderConfigured && !root.isLoading
            hoverEnabled: root.isProviderConfigured && !root.isLoading

            onClicked: root.clearChatRequested()

            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            PlasmaComponents.ToolTip.visible: hovered
        }

        PlasmaComponents.ComboBox {
            id: modelsCombobox
            visible: root.currentProvider === "ollama"
            enabled: root.hasLocalModel && !root.isLoading
            hoverEnabled: root.hasLocalModel && !root.isLoading

            Layout.fillWidth: true

            model: root.modelsArray.map(model => model.text)

            onActivated: {
                const selectedModel = root.modelsArray.find(model => model.text === modelsCombobox.currentText);
                if (selectedModel) {
                    root.modelSelected(selectedModel.value);
                }
            }
        }

        PlasmaComponents.Label {
            visible: root.currentProvider === "openclaw"
            Layout.fillWidth: true
            text: "OpenClaw"
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            visible: root.currentProvider === "openai-compatible"
            Layout.fillWidth: true

            PlasmaComponents.Label {
                text: root.openaiCompatibleModelName || "OpenAI Compatible"
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.CheckBox {
                id: thinkingCheckbox
                text: i18n("Thinking")
                checked: root.thinkingEnabled
                onCheckedChanged: {
                    if (checked !== root.thinkingEnabled) {
                        Plasmoid.configuration.openaiCompatibleDisableThinking = !checked
                        root.thinkingEnabled = checked
                    }
                }

                PlasmaComponents.ToolTip.text: i18n("Toggle thinking/reasoning mode. Disable for faster responses.")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
            }
        }

        PlasmaComponents.ToolButton {
            id: pinButton
            checkable: true
            checked: Plasmoid.configuration.pin
            onToggled: Plasmoid.configuration.pin = checked
            icon.name: "window-pin"

            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Keep Open")

            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            PlasmaComponents.ToolTip.visible: hovered
        }
    }
}
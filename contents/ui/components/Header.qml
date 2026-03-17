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
    signal providerSelected(string provider, string model)
    signal pinToggled(bool checked)
    signal thinkingToggled(bool enabled)

    property bool isLoading: false
    property string currentProvider: "ollama"
    property string currentModel: ""
    property var ollamaModels: []
    property bool enableOllama: true
    property bool enableOpenClaw: false
    property bool enableOpenAICompatible: false
    property string openaiCompatibleModelName: ""
    property bool thinkingEnabled: true
    property var listModelController: null
    property bool pinChecked: false

    width: parent.width

    function buildProviderModel() {
        var items = []

        if (enableOpenClaw) {
            items.push({
                text: "OpenClaw",
                provider: "openclaw",
                model: ""
            })
        }

        if (enableOpenAICompatible && openaiCompatibleModelName) {
            items.push({
                text: openaiCompatibleModelName + " (OpenAI Compatible)",
                provider: "openai-compatible",
                model: openaiCompatibleModelName
            })
        }

        if (enableOllama && ollamaModels.length > 0) {
            ollamaModels.forEach(function(modelObj) {
                items.push({
                    text: modelObj.text + " (Ollama)",
                    provider: "ollama",
                    model: modelObj.value
                })
            })
        }

        return items
    }

    contentItem: RowLayout {
        Layout.fillWidth: true

        PlasmaComponents.ToolButton {
            icon.name: "edit-clear-history-symbolic"
            text: i18n("Clear chat")
            display: PlasmaComponents.AbstractButton.IconOnly
            enabled: providerComboBox.count > 0 && !root.isLoading
            hoverEnabled: providerComboBox.count > 0 && !root.isLoading

            onClicked: root.clearChatRequested()

            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            PlasmaComponents.ToolTip.visible: hovered
        }

        PlasmaComponents.ComboBox {
            id: providerComboBox

            Layout.fillWidth: true
            enabled: count > 0 && !root.isLoading
            hoverEnabled: count > 0 && !root.isLoading

            model: root.buildProviderModel().map(function(item) { return item.text })

            property var itemsModel: root.buildProviderModel()

            onActivated: {
                var selectedItem = itemsModel[currentIndex]
                if (selectedItem) {
                    root.providerSelected(selectedItem.provider, selectedItem.model)
                }
            }

            Component.onCompleted: {
                updateCurrentIndex()
            }

            function updateCurrentIndex() {
                var items = itemsModel
                for (var i = 0; i < items.length; i++) {
                    if (items[i].provider === root.currentProvider) {
                        if (root.currentProvider === "ollama" && items[i].model === root.currentModel) {
                            currentIndex = i
                            return
                        } else if (root.currentProvider !== "ollama") {
                            currentIndex = i
                            return
                        }
                    }
                }
            }

            Connections {
                target: root
                function onCurrentProviderChanged() { providerComboBox.updateCurrentIndex() }
                function onCurrentModelChanged() { providerComboBox.updateCurrentIndex() }
                function onOllamaModelsChanged() { providerComboBox.itemsModel = root.buildProviderModel() }
                function onEnableOllamaChanged() { providerComboBox.itemsModel = root.buildProviderModel() }
                function onEnableOpenClawChanged() { providerComboBox.itemsModel = root.buildProviderModel() }
                function onEnableOpenAICompatibleChanged() { providerComboBox.itemsModel = root.buildProviderModel() }
                function onOpenaiCompatibleModelNameChanged() { providerComboBox.itemsModel = root.buildProviderModel() }
            }
        }

        PlasmaComponents.CheckBox {
            visible: root.currentProvider === "openai-compatible"
            text: i18n("Thinking")
            checked: root.thinkingEnabled
            onCheckedChanged: {
                if (checked !== root.thinkingEnabled) {
                    root.thinkingToggled(checked)
                }
            }

            PlasmaComponents.ToolTip.text: i18n("Toggle thinking/reasoning mode. Disable for faster responses.")
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            PlasmaComponents.ToolTip.visible: hovered
        }

        PlasmaComponents.ToolButton {
            id: pinButton
            checkable: true
            checked: root.pinChecked
            onToggled: root.pinToggled(checked)
            icon.name: "window-pin"

            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Keep Open")

            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            PlasmaComponents.ToolTip.visible: hovered
        }
    }
}
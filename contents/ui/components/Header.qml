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
    property string currentProvider: "ollama-0"
    property string currentModel: ""
    property var ollamaModels: []
    property var providers: []
    property bool thinkingEnabled: true
    property var listModelController: null
    property bool pinChecked: false

    width: parent.width

    function buildProviderModel() {
        var items = []

        for (var i = 0; i < providers.length; i++) {
            var provider = providers[i];
            if (provider.enabled === false) continue;

            if (provider.type === "ollama" && ollamaModels.length > 0) {
                ollamaModels.forEach(function(modelObj) {
                    items.push({
                        text: modelObj.text,
                        provider: "ollama-" + i,
                        model: modelObj.value
                    })
                })
            } else if (provider.type === "openclaw") {
                items.push({
                    text: provider.displayName || "OpenClaw",
                    provider: "openclaw-" + i,
                    model: ""
                })
            } else if (provider.type === "openai-compatible") {
                var displayName = provider.displayName || ("Provider " + (i + 1));
                items.push({
                    text: displayName + " (" + (provider.model || i18n("No model")) + ")",
                    provider: "openai-compatible-" + i,
                    model: provider.model || ""
                })
            }
        }

        return items
    }

    contentItem: RowLayout {
        Layout.fillWidth: true

        PlasmaComponents.ToolButton {
            icon.name: "contact-new-symbolic"
            text: i18n("New chat")
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

            model: itemsModel.map(function(item) { return item.text })

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
                        if (items[i].provider.startsWith("ollama-") && items[i].model === root.currentModel) {
                            currentIndex = i
                            return
                        } else if (!items[i].provider.startsWith("ollama-")) {
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
                function onProvidersChanged() { providerComboBox.itemsModel = root.buildProviderModel() }
            }
        }

        PlasmaComponents.CheckBox {
            visible: root.currentProvider.startsWith("openai-compatible-")
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

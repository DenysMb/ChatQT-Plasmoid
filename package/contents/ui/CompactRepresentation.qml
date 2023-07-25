import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: compactRep

    RowLayout {
        anchors.fill: parent
        
        PlasmaCore.IconItem {
            Layout.fillWidth: true
            Layout.fillHeight: true

            source: Plasmoid.icon || "plasma"
            smooth: true
            active: mouseArea.containsMouse
            
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    plasmoid.expanded = !plasmoid.expanded

                    messageFieldActiveFocusTimer.start();
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

Loader {
    property var models;

    TapHandler {
        property bool wasExpanded: false

        acceptedButtons: Qt.LeftButton

        onPressedChanged: if (pressed) {
            wasExpanded = root.expanded;
        }
        onTapped: root.expanded = !wasExpanded
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: Qt.resolvedUrl(getIcon())
    }

    function getIcon() {
        const colorContrast = getBackgroundColorContrast();

        if (Plasmoid.configuration.useFilledDarkIcon) {
            return "assets/logo-filled-dark.svg";
        } else if (Plasmoid.configuration.useFilledLightIcon) {
            return "assets/logo-filled-light.svg";
        } else if (Plasmoid.configuration.useOutlinedDarkIcon) {
            return "assets/logo-outlined-dark.svg";
        } else if (Plasmoid.configuration.useOutlinedLightIcon) {
            return "assets/logo-outlined-light.svg";
        } if (Plasmoid.configuration.useOutlinedIcon) {
            return `assets/logo-outlined-${colorContrast}.svg`;
        } else {
            return `assets/logo-filled-${colorContrast}.svg`;
        }
    }

    function getBackgroundColorContrast() {
        const hex = `${PlasmaCore.Theme.backgroundColor}`.substring(1);
        const r = parseInt(hex.substring(0, 2), 16);
        const g = parseInt(hex.substring(2, 4), 16);
        const b = parseInt(hex.substring(4, 6), 16);
        const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        
        return luma > 128 ? "dark" : "light";
    }
}
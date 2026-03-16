import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

Item {
    id: compactRoot

    property var models: []

    MouseArea {
        id: mouseArea
        anchors.fill: parent

        onClicked: root.expanded = !root.expanded
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: getIconSource()
    }

    function getIconSource() {
        let icon = getIconPath();
        if (icon.indexOf("/") !== -1 || icon.endsWith(".svg") || icon.endsWith(".png")) {
            return Qt.resolvedUrl(icon);
        }
        return icon;
    }

    function getIconPath() {
        const style = plasmoid.configuration.iconStyle || "filled-adaptive";
        const colorContrast = getBackgroundColorContrast();

        switch (style) {
            case "filled-dark":
                return "assets/logo-filled-dark.svg";
            case "filled-light":
                return "assets/logo-filled-light.svg";
            case "outlined-dark":
                return "assets/logo-outlined-dark.svg";
            case "outlined-light":
                return "assets/logo-outlined-light.svg";
            case "outlined-adaptive":
                return `assets/logo-outlined-${colorContrast}.svg`;
            case "filled-adaptive":
            default:
                return `assets/logo-filled-${colorContrast}.svg`;
        }
    }

    function getBackgroundColorContrast() {
        const color = Kirigami.Theme.backgroundColor;
        const luma = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
        return luma > 0.5 ? "dark" : "light";
    }
}
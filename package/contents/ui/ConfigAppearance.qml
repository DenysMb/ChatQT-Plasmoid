import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.iconthemes as KIconThemes
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.kcmutils as KCM

import org.kde.plasma.core as PlasmaCore

KCM.SimpleKCM {
    property string cfg_icon: plasmoid.configuration.icon
    property alias cfg_useFilledIcon: useFilledIcon.checked
    property alias cfg_useOutlinedIcon: useOutlinedIcon.checked
    property alias cfg_useFilledLightIcon: useFilledLightIcon.checked
    property alias cfg_useFilledDarkIcon: useFilledDarkIcon.checked
    property alias cfg_useOutlinedLightIcon: useOutlinedLightIcon.checked
    property alias cfg_useOutlinedDarkIcon: useOutlinedDarkIcon.checked

    Kirigami.FormLayout {

        QQC2.ButtonGroup {
            id: iconGroup
        }

        QQC2.RadioButton {
            id: useFilledIcon

            Kirigami.FormData.label: i18nc("@title:group", "Icon:")
            text: i18nc("@option:radio", "Filled adaptive icon")

            QQC2.ButtonGroup.group: iconGroup
        }

        QQC2.RadioButton {
            id: useOutlinedIcon

            text: i18nc("@option:radio", "Outlined adaptive icon")

            QQC2.ButtonGroup.group: iconGroup
        }

        QQC2.RadioButton {
            id: useFilledDarkIcon

            text: i18nc("@option:radio", "Filled dark icon")

            QQC2.ButtonGroup.group: iconGroup
        }

        QQC2.RadioButton {
            id: useFilledLightIcon

            text: i18nc("@option:radio", "Filled light icon")

            QQC2.ButtonGroup.group: iconGroup
        }

        QQC2.RadioButton {
            id: useOutlinedDarkIcon

            text: i18nc("@option:radio", "Outlined dark icon")

            QQC2.ButtonGroup.group: iconGroup
        }

        QQC2.RadioButton {
            id: useOutlinedLightIcon

            text: i18nc("@option:radio", "Outlined light icon")

            QQC2.ButtonGroup.group: iconGroup
        }
    }
}

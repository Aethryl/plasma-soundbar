import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property string cfg_style
    property alias cfg_marqueeWidth: marqueeWidth.value
    property alias cfg_showCover: showCover.checked
    property alias cfg_collapseAfter: collapseAfter.value
    property alias cfg_tintFromCover: tintFromCover.checked

    readonly property var styles: ["auto", "marquee", "equalizer"]

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: "Bar style:"
            model: ["Automatic", "Cover and title", "Block equalizer"]
            currentIndex: Math.max(0, styles.indexOf(cfg_style))
            onActivated: index => cfg_style = styles[index]
        }
        QQC2.Label {
            text: "Automatic shows the cover and title when the panel has room, otherwise the equalizer."
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            opacity: 0.7
        }
        QQC2.SpinBox {
            id: marqueeWidth
            Kirigami.FormData.label: "Title width:"
            from: 6
            to: 30
            textFromValue: value => value + " units"
        }
        QQC2.CheckBox {
            id: showCover
            Kirigami.FormData.label: "Cover:"
            text: "Show the cover in the bar"
        }
        QQC2.SpinBox {
            id: collapseAfter
            Kirigami.FormData.label: "Collapse when paused for:"
            from: 0
            to: 120
            textFromValue: value => value === 0 ? "never" : value + " min"
        }
        QQC2.CheckBox {
            id: tintFromCover
            Kirigami.FormData.label: "Dropdown:"
            text: "Tint the dropdown with the cover's colour"
        }
    }
}

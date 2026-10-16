import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    readonly property var player: mpris.currentPlayer
    readonly property string track: player ? player.track || "" : ""
    readonly property string artist: player ? player.artist || "" : ""
    readonly property string album: player ? player.album || "" : ""
    readonly property string artUrl: player ? player.artUrl || "" : ""
    readonly property string identity: player ? player.identity || "" : ""
    readonly property int status: player ? player.playbackStatus : Mpris.PlaybackStatus.Unknown
    readonly property bool playing: status === Mpris.PlaybackStatus.Playing
    readonly property bool present: !!player && (track !== "" || status > Mpris.PlaybackStatus.Stopped)
    readonly property real length: player ? player.length || 0 : 0
    readonly property real position: player ? player.position || 0 : 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0
    readonly property string title: track + (artist ? " — " + artist : "")
    property real pausedAt: 0
    property real now: Date.now()
    readonly property bool collapsed: !playing && Plasmoid.configuration.collapseAfter > 0 && pausedAt > 0
        && now - pausedAt > Plasmoid.configuration.collapseAfter * 60000
    property bool drooped: false
    property Item compactItem: null
    property real compactWidth: Kirigami.Units.gridUnit * 6

    readonly property real ear: Kirigami.Units.gridUnit * 0.7
    readonly property real bottomRadius: Kirigami.Units.gridUnit * 1.1
    readonly property color accent: Kirigami.Theme.positiveTextColor
    readonly property color dim: Kirigami.Theme.disabledTextColor
    readonly property color hairline: Qt.alpha(Kirigami.Theme.textColor, 0.1)

    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    fullRepresentation: Item {}
    Plasmoid.backgroundHints: "NoBackground"
    Plasmoid.status: present ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: ""
    toolTipSubText: ""

    onPlayingChanged: pausedAt = playing ? 0 : Date.now()
    onPresentChanged: if (!present) drooped = false

    Mpris.Mpris2Model { id: mpris }

    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now()
            if (root.player)
                root.player.updatePosition()
        }
    }
    Timer {
        interval: 30000
        running: !root.playing && root.pausedAt > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    function clock(us) {
        const s = Math.max(0, Math.floor(us / 1000000))
        const h = Math.floor(s / 3600)
        const m = Math.floor(s % 3600 / 60)
        const sec = String(s % 60).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec
    }

    function wheel(delta) {
        if (root.player)
            root.player.changeVolume(delta > 0 ? 0.05 : -0.05, true)
    }

    component Equalizer: Item {
        id: eq
        property int columns: 5
        property bool live: root.playing
        readonly property real dpr: Screen.devicePixelRatio || 1
        readonly property real cell: Math.max(2, Math.round(Kirigami.Units.gridUnit * 0.2 * dpr)) / dpr
        readonly property real gap: Math.max(1, Math.round(dpr)) / dpr
        readonly property int rows: 5
        property var heights: []
        implicitWidth: columns * cell + (columns - 1) * gap
        implicitHeight: rows * cell + (rows - 1) * gap

        function shuffle() {
            const next = []
            for (let i = 0; i < columns; i++)
                next.push(live ? 1 + Math.floor(Math.random() * rows) : 1)
            heights = next
        }
        Component.onCompleted: shuffle()
        onLiveChanged: shuffle()

        Timer {
            interval: 160
            running: eq.live && eq.visible && Kirigami.Units.longDuration > 0
            repeat: true
            onTriggered: eq.shuffle()
        }
        Row {
            spacing: eq.gap
            anchors.bottom: parent.bottom
            Repeater {
                model: eq.columns
                Column {
                    required property int index
                    spacing: eq.gap
                    Repeater {
                        model: eq.rows
                        Rectangle {
                            required property int index
                            width: eq.cell
                            height: eq.cell
                            color: eq.rows - index <= (eq.heights[parent.index] || 1) ? root.accent : Qt.alpha(root.accent, 0.18)
                        }
                    }
                }
            }
        }
    }

    component Wave: Item {
        id: wave
        property real fraction: 0
        property bool running: true
        property real stroke: hair * 1.5
        property real wavelength: 3.2
        property bool interactive: false
        property real dragFraction: -1
        signal seek(real fraction)
        readonly property real dpr: Screen.devicePixelRatio || 1
        readonly property real hair: Math.max(1, Math.round(dpr)) / dpr
        readonly property real shown: dragFraction >= 0 ? dragFraction : fraction
        readonly property real mid: Math.round(height / 2 * dpr) / dpr
        readonly property real played: Math.round(width * Math.min(1, Math.max(0, shown)))
        property real phase: 0
        property real amplitude: root.playing ? (height - stroke) / 2 : 0
        Behavior on amplitude { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        NumberAnimation on phase {
            running: root.playing && wave.running && wave.visible && Kirigami.Units.longDuration > 0
            from: 0
            to: Math.PI * 2
            duration: 1400
            loops: Animation.Infinite
        }
        Rectangle {
            x: wave.played
            y: wave.mid - wave.hair / 2
            width: Math.max(0, wave.width - wave.played)
            height: wave.hair
            color: Qt.alpha(Kirigami.Theme.textColor, 0.18)
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: wave.played > 1
            ShapePath {
                strokeColor: root.accent
                strokeWidth: wave.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: {
                        const points = []
                        const end = wave.played
                        for (let x = 0; x <= end; x += 1) {
                            const fade = Math.min(1, x / (wave.wavelength * 3), (end - x) / (wave.wavelength * 2))
                            points.push(Qt.point(x, wave.mid - Math.sin(x / wave.wavelength - wave.phase) * wave.amplitude * fade))
                        }
                        return points
                    }
                }
            }
        }
        Repeater {
            model: wave.played > 1 ? [0] : []
            Rectangle {
                required property real modelData
                readonly property real size: Math.round(wave.stroke * 2.6 * wave.dpr) / wave.dpr
                x: modelData - size / 2
                y: wave.mid - size / 2
                width: size
                height: size
                radius: size / 2
                color: root.accent
            }
        }
        Rectangle {
            visible: wave.interactive && (seekArea.containsMouse || seekArea.pressed)
            x: wave.played - width / 2
            y: wave.mid - height / 2
            width: wave.stroke * 3
            height: wave.height * 0.9
            radius: width / 2
            color: root.accent
        }
        MouseArea {
            id: seekArea
            anchors.fill: parent
            anchors.topMargin: -Kirigami.Units.smallSpacing * 2
            anchors.bottomMargin: -Kirigami.Units.smallSpacing * 2
            enabled: wave.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.min(1, Math.max(0, x / wave.width)) }
            onPressed: mouse => wave.dragFraction = at(mouse.x)
            onPositionChanged: mouse => { if (pressed) wave.dragFraction = at(mouse.x) }
            onReleased: mouse => {
                wave.seek(at(mouse.x))
                wave.dragFraction = -1
            }
        }
    }

    component Line: Item {
        id: line
        property real fraction: 0
        signal moved(real fraction)
        readonly property real dpr: Screen.devicePixelRatio || 1
        readonly property real hair: Math.max(1, Math.round(dpr)) / dpr
        implicitHeight: Kirigami.Units.gridUnit
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: line.hair
            color: Qt.alpha(Kirigami.Theme.textColor, 0.18)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.min(1, Math.max(0, line.fraction))
            height: line.hair * 2
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: 0.75
        }
        Rectangle {
            visible: lineArea.containsMouse || lineArea.pressed
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * line.fraction - width / 2
            width: line.hair * 5
            height: Kirigami.Units.gridUnit * 0.6
            radius: width / 2
            color: Kirigami.Theme.textColor
        }
        MouseArea {
            id: lineArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.min(1, Math.max(0, x / width)) }
            onPressed: mouse => line.moved(at(mouse.x))
            onPositionChanged: mouse => { if (pressed) line.moved(at(mouse.x)) }
            onWheel: wheel => line.moved(Math.min(1, Math.max(0, line.fraction + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    component Cover: Item {
        id: cover
        property real radius: Kirigami.Units.cornerRadius
        Rectangle {
            anchors.fill: parent
            radius: cover.radius
            color: Qt.alpha(root.accent, 0.25)
            visible: art.status !== Image.Ready
            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                source: "media-album-cover"
                isMask: true
                color: root.accent
            }
        }
        Image {
            id: art
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
        Rectangle {
            id: mask
            anchors.fill: parent
            radius: cover.radius
            visible: false
            layer.enabled: true
        }
    }

    compactRepresentation: MouseArea {
        id: compact
        readonly property real marqueeSpan: Kirigami.Units.gridUnit * Plasmoid.configuration.marqueeWidth
        readonly property real fullWidth: (Plasmoid.configuration.showCover ? cover.width + row.spacing : 0) + marqueeSpan
        readonly property real eqWidth: eqRow.implicitWidth
        readonly property string style: Plasmoid.configuration.style
        readonly property real padMax: Kirigami.Units.gridUnit * 1.5
        readonly property real padMin: Kirigami.Units.smallSpacing
        readonly property real content: root.collapsed ? collapsedEq.implicitWidth : marquee ? fullWidth : eqWidth
        readonly property real pad: Math.max(padMin, Math.min(padMax, (width - content) / 2))
        readonly property bool marquee: !root.collapsed && (style === "marquee" || (style === "auto" && width >= fullWidth + padMin * 2 - 1))
        Layout.minimumWidth: root.present ? (root.collapsed ? collapsedEq.implicitWidth : eqWidth) + padMin * 2 : 0
        Layout.preferredWidth: root.present ? (root.collapsed ? collapsedEq.implicitWidth : style === "equalizer" ? eqWidth : fullWidth) + padMax * 2 : 0
        Layout.maximumWidth: Layout.preferredWidth
        Layout.fillWidth: style === "auto" && !root.collapsed
        visible: root.present
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        Component.onCompleted: root.compactItem = compact
        onWidthChanged: root.compactWidth = width
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton && root.player)
                root.player.PlayPause()
            else
                root.drooped = !root.drooped
        }
        onWheel: wheel => root.wheel(wheel.angleDelta.y)

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: compact.pad
            anchors.rightMargin: compact.pad
            visible: compact.marquee
            spacing: Kirigami.Units.smallSpacing * 1.5
            Cover {
                id: cover
                visible: Plasmoid.configuration.showCover
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                radius: Kirigami.Units.cornerRadius / 2
            }
            Item {
                id: lane
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property bool scrolls: measure.width > width
                TextMetrics {
                    id: measure
                    font: label.font
                    text: root.title
                }
                readonly property real dpr: Screen.devicePixelRatio || 1
                readonly property real hair: Math.max(1, Math.round(dpr)) / dpr
                readonly property real capHeight: -capMeasure.tightBoundingRect.y
                readonly property real glyphTop: fontMetrics.ascent - capHeight
                readonly property real gap: Math.ceil(fontMetrics.descent) + hair * 2
                readonly property real waveHeight: Kirigami.Units.smallSpacing * 1.25
                readonly property real stackTop: Math.round(((height - capHeight - gap - waveHeight) / 2 - hair) * lane.dpr) / lane.dpr
                FontMetrics {
                    id: fontMetrics
                    font: label.font
                }
                TextMetrics {
                    id: capMeasure
                    font: label.font
                    text: "H"
                }
                Item {
                    id: ticker
                    y: lane.stackTop - lane.glyphTop
                    width: lane.width
                    height: Math.ceil(label.contentHeight)
                    clip: true
                PlasmaComponents.Label {
                    id: label
                    topPadding: 0
                    bottomPadding: 0
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                    text: lane.scrolls ? root.title + "     ·     " + root.title + "     ·     " : root.title
                    color: root.playing ? Kirigami.Theme.textColor : root.dim
                    property real shift: 0
                    x: lane.scrolls ? -shift : 0
                    NumberAnimation on shift {
                        running: lane.scrolls && root.playing && compact.marquee && Kirigami.Units.longDuration > 0
                        from: 0
                        to: label.implicitWidth / 2
                        duration: label.implicitWidth / 2 * 45
                        loops: Animation.Infinite
                    }
                }
                }
                Wave {
                    y: lane.stackTop + lane.capHeight + lane.gap
                    width: lane.width
                    height: lane.waveHeight
                    fraction: root.progress
                    running: compact.marquee
                }
            }
        }

        RowLayout {
            id: eqRow
            anchors.centerIn: parent
            visible: !compact.marquee && !root.collapsed
            spacing: Kirigami.Units.smallSpacing * 1.5
            Equalizer { Layout.alignment: Qt.AlignVCenter }
            PlasmaComponents.Label {
                text: root.track
                elide: Text.ElideRight
                color: root.playing ? Kirigami.Theme.textColor : root.dim
                Layout.maximumWidth: Kirigami.Units.gridUnit * 5
            }
        }

        Equalizer {
            id: collapsedEq
            anchors.centerIn: parent
            visible: root.collapsed
            columns: 3
        }
    }

    onDroopedChanged: {
        if (drooped) {
            droop.visible = true
            droop.requestActivate()
            reveal.to = 1
            reveal.easing.type = Easing.OutBack
            reveal.duration = 320
        } else {
            reveal.to = 0
            reveal.easing.type = Easing.InCubic
            reveal.duration = 160
        }
        reveal.restart()
    }

    NumberAnimation {
        id: reveal
        target: notch
        property: "progress"
        onFinished: if (!root.drooped) droop.visible = false
    }

    Kirigami.ImageColors {
        id: coverColors
        source: root.artUrl
        Component.onCompleted: update()
    }
    onArtUrlChanged: coverColors.update()

    PlasmaCore.Dialog {
        id: droop
        visualParent: root.compactItem
        location: PlasmaCore.Types.TopEdge
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        onVisibleChanged: if (!visible) { root.drooped = false; notch.progress = 0 }

        mainItem: Item {
            id: notch
            property real progress: 0
            focus: true
            Keys.onEscapePressed: root.drooped = false
            Keys.onSpacePressed: if (root.player) root.player.PlayPause()
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false
            readonly property real bodyWidth: Math.max(root.compactWidth, Kirigami.Units.gridUnit * 19)
            readonly property real fullHeight: content.implicitHeight + Kirigami.Units.gridUnit * 1.6
            readonly property real shownHeight: Math.max(0, fullHeight * progress)
            readonly property color fill: {
                const base = Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.textColor, 0.08))
                return Plasmoid.configuration.tintFromCover && coverColors.palette.length
                    ? Qt.tint(base, Qt.alpha(coverColors.dominant, 0.12)) : base
            }
            width: bodyWidth + root.ear * 2
            height: fullHeight * 1.1

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    id: sp
                    readonly property real e: root.ear
                    readonly property real w: notch.bodyWidth
                    readonly property real h: Math.max(notch.shownHeight, e + 1)
                    readonly property real r: Math.min(root.bottomRadius, h - e)
                    strokeWidth: -1
                    fillColor: notch.fill
                    startX: 0; startY: 0
                    PathQuad { controlX: sp.e; controlY: 0; x: sp.e; y: sp.e }
                    PathLine { x: sp.e; y: sp.h - sp.r }
                    PathQuad { controlX: sp.e; controlY: sp.h; x: sp.e + sp.r; y: sp.h }
                    PathLine { x: sp.e + sp.w - sp.r; y: sp.h }
                    PathQuad { controlX: sp.e + sp.w; controlY: sp.h; x: sp.e + sp.w; y: sp.h - sp.r }
                    PathLine { x: sp.e + sp.w; y: sp.e }
                    PathQuad { controlX: sp.e + sp.w; controlY: 0; x: sp.e * 2 + sp.w; y: 0 }
                    PathLine { x: 0; y: 0 }
                }
            }

            Item {
                x: root.ear
                width: notch.bodyWidth
                height: notch.shownHeight
                clip: true

                ColumnLayout {
                    id: content
                    x: Kirigami.Units.gridUnit * 0.9
                    y: Kirigami.Units.gridUnit * 0.7
                    width: parent.width - Kirigami.Units.gridUnit * 1.8
                    spacing: Kirigami.Units.largeSpacing
                    opacity: Math.min(1, Math.max(0, notch.progress * 1.6 - 0.4))

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing * 1.5
                        Cover {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                            radius: Kirigami.Units.cornerRadius * 2
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            PlasmaComponents.Label {
                                text: root.identity
                                color: root.accent
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 1
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: root.track || "Nothing playing"
                                font.weight: Font.DemiBold
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: root.artist
                                color: root.dim
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: root.album
                                color: root.dim
                                elide: Text.ElideRight
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.length > 0
                        spacing: Kirigami.Units.smallSpacing * 2
                        PlasmaComponents.Label {
                            text: root.clock(seek.dragFraction >= 0 ? seek.dragFraction * root.length : root.position)
                            color: root.dim
                            font.family: "monospace"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                        Wave {
                            id: seek
                            Layout.fillWidth: true
                            Layout.preferredHeight: Kirigami.Units.smallSpacing * 3
                            fraction: root.progress
                            stroke: hair * 2.5
                            wavelength: 4.5
                            running: notch.progress > 0
                            interactive: !!root.player && root.player.canSeek
                            onSeek: fraction => { if (root.player) root.player.position = fraction * root.length }
                        }
                        PlasmaComponents.Label {
                            text: root.clock(root.length)
                            color: root.dim
                            font.family: "monospace"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Kirigami.Units.gridUnit
                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-backward"
                            enabled: !!root.player && root.player.canGoPrevious
                            onClicked: root.player.Previous()
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                            icon.width: Kirigami.Units.iconSizes.medium
                            icon.height: Kirigami.Units.iconSizes.medium
                            enabled: !!root.player && (root.playing ? root.player.canPause : root.player.canPlay)
                            onClicked: root.player.PlayPause()
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-forward"
                            enabled: !!root.player && root.player.canGoNext
                            onClicked: root.player.Next()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !!root.player && root.player.canControl
                        spacing: Kirigami.Units.smallSpacing * 2
                        Kirigami.Icon {
                            source: "audio-volume-medium"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            color: root.dim
                            isMask: true
                        }
                        Line {
                            Layout.fillWidth: true
                            fraction: root.player ? root.player.volume : 0
                            onMoved: fraction => { if (root.player) root.player.volume = fraction }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.hairline
                        visible: players.count > 2
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        visible: players.count > 2
                        Repeater {
                            id: players
                            model: mpris
                            delegate: Rectangle {
                                required property int index
                                required property var model
                                readonly property bool current: mpris.currentIndex === index
                                width: chip.implicitWidth + Kirigami.Units.largeSpacing * 2
                                height: chip.implicitHeight + Kirigami.Units.smallSpacing * 1.5
                                radius: height / 2
                                color: current ? Qt.alpha(root.accent, 0.22) : chipHover.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.12) : Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                PlasmaComponents.Label {
                                    id: chip
                                    anchors.centerIn: parent
                                    text: index === 0 ? "Follow active" : model.identity
                                    color: parent.current ? root.accent : Kirigami.Theme.textColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                }
                                MouseArea {
                                    id: chipHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mpris.currentIndex = parent.index
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

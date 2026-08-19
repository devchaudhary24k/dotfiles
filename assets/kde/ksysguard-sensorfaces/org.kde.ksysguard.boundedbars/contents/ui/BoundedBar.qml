/* SPDX-License-Identifier: GPL-2.0-or-later */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

ProgressBar {
    id: bar

    Layout.fillWidth: true

    required property Sensors.Sensor sensor
    required property color barColor
    required property real lowerBound
    required property real upperBound

    from: lowerBound
    to: Math.max(upperBound, lowerBound + 0.000001)
    value: Number(sensor.value ?? 0)

    topPadding: topInset
    bottomPadding: bottomInset

    contentItem: Item {
        Rectangle {
            width: Math.max(0, Math.min(1, bar.visualPosition)) * parent.width
            height: parent.height
            color: bar.barColor
            radius: height / 2
        }
    }

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: Kirigami.Units.largeSpacing
        color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)
        radius: height / 2
    }
}

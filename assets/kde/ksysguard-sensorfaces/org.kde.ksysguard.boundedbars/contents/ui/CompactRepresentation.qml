/* SPDX-License-Identifier: GPL-2.0-or-later */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces

Faces.CompactSensorFace {
    id: root

    readonly property int barCount: controller.highPrioritySensorIds.length
    readonly property real minimumTotalHeight: Kirigami.Units.smallSpacing * barCount + Math.max(0, barCount - 1)
    Layout.minimumHeight: verticalFormFactor ? Math.max(minimumTotalHeight, Kirigami.Units.gridUnit) : defaultMinimumSize

    readonly property var minimumMap: parseBounds(controller.faceConfiguration.minimums)
    readonly property var maximumMap: parseBounds(controller.faceConfiguration.maximums)

    function parseBounds(rawValue) {
        try {
            return typeof rawValue === "object" && rawValue !== null ? rawValue : JSON.parse(String(rawValue || "{}"));
        } catch (error) {
            return {};
        }
    }

    function finiteNumber(value) {
        const number = Number(value);
        return Number.isFinite(number) ? number : NaN;
    }

    function lowerBound(sensor) {
        const configured = finiteNumber(minimumMap[sensor.sensorId]);
        if (Number.isFinite(configured)) {
            return configured;
        }
        const reported = finiteNumber(sensor.minimum);
        return Number.isFinite(reported) ? reported : 0;
    }

    function upperBound(sensor) {
        const lower = lowerBound(sensor);
        const configured = finiteNumber(maximumMap[sensor.sensorId]);
        if (Number.isFinite(configured) && configured > lower) {
            return configured;
        }
        const reported = finiteNumber(sensor.maximum);
        if (Number.isFinite(reported) && reported > lower) {
            return reported;
        }
        const current = Math.abs(finiteNumber(sensor.value));
        return Number.isFinite(current) && current > lower ? current * 1.25 : lower + 1;
    }

    contentItem: ColumnLayout {
        spacing: 1

        Item { Layout.fillWidth: true }

        Repeater {
            model: root.controller.highPrioritySensorIds

            BoundedBar {
                required property string modelData

                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.smallSpacing
                Layout.maximumHeight: Kirigami.Units.largeSpacing
                topInset: 0
                bottomInset: 0
                opacity: y + height <= root.height
                sensor: sensor
                barColor: root.colorSource.map[modelData] ?? Kirigami.Theme.highlightColor
                lowerBound: root.lowerBound(sensor)
                upperBound: root.upperBound(sensor)

                Sensors.Sensor {
                    id: sensor
                    sensorId: modelData
                    updateRateLimit: root.controller.updateRateLimit
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}

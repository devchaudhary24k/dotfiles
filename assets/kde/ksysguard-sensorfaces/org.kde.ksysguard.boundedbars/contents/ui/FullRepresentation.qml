/* SPDX-License-Identifier: GPL-2.0-or-later */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces
import org.kde.quickcharts.controls as ChartsControls

Faces.SensorFace {
    id: root

    Layout.minimumWidth: Kirigami.Units.gridUnit * 8
    Layout.preferredWidth: titleMetrics.width

    readonly property var minimumMap: parseBounds(controller.faceConfiguration.minimums)
    readonly property var maximumMap: parseBounds(controller.faceConfiguration.maximums)

    function parseBounds(rawValue) {
        if (typeof rawValue === "object" && rawValue !== null) {
            return rawValue;
        }
        try {
            return JSON.parse(String(rawValue || "{}"));
        } catch (error) {
            console.warn("Bounded Horizontal Bars: invalid bounds JSON", error);
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
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            id: heading
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.controller.title
            visible: root.controller.showTitle && text.length > 0
            level: 2

            TextMetrics {
                id: titleMetrics
                font: heading.font
                text: heading.text
            }
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        Repeater {
            model: root.controller.highPrioritySensorIds

            ColumnLayout {
                required property string modelData

                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: 0

                BoundedBar {
                    sensor: sensor
                    barColor: root.colorSource.map[modelData] ?? Kirigami.Theme.highlightColor
                    lowerBound: root.lowerBound(sensor)
                    upperBound: root.upperBound(sensor)
                }

                ChartsControls.LegendDelegate {
                    Layout.fillWidth: true
                    Layout.minimumHeight: implicitHeight
                    name: root.controller.sensorLabels[sensor.sensorId] || sensor.name
                    shortName: root.controller.sensorLabels[sensor.sensorId] || sensor.shortName
                    value: sensor.formattedValue
                    indicator: Item {}
                    maximumValueWidth: Kirigami.Units.gridUnit * 3
                }

                Sensors.Sensor {
                    id: sensor
                    sensorId: modelData
                    updateRateLimit: root.controller.updateRateLimit
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: root.controller.lowPrioritySensorIds.length > 0
        }

        Repeater {
            model: root.controller.lowPrioritySensorIds

            ChartsControls.LegendDelegate {
                required property string modelData

                Layout.fillWidth: true
                Layout.minimumHeight: implicitHeight
                name: root.controller.sensorLabels[sensor.sensorId] || sensor.shortName
                value: sensor.formattedValue
                indicator: Item {}
                maximumValueWidth: Kirigami.Units.gridUnit * 3

                Sensors.Sensor {
                    id: sensor
                    sensorId: modelData
                    updateRateLimit: root.controller.updateRateLimit
                }
            }
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }
    }
}

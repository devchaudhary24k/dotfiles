/* SPDX-License-Identifier: GPL-2.0-or-later */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_minimums: minimumsField.text
    property alias cfg_maximums: maximumsField.text

    QQC2.TextArea {
        id: minimumsField
        Kirigami.FormData.label: "Per-sensor minimums (JSON):"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        wrapMode: TextEdit.WrapAnywhere
    }

    QQC2.TextArea {
        id: maximumsField
        Kirigami.FormData.label: "Per-sensor maximums (JSON):"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        wrapMode: TextEdit.WrapAnywhere
    }
}

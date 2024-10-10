import QtQuick
import QtQuick.Controls

import QGroundControl.Palette
import QGroundControl.ScreenTools

Text {
    property real fontSizeQGCLabel: ScreenTools.defaultFontPointSize

    font.pointSize: fontSizeQGCLabel
    font.family:    ScreenTools.normalFontFamily
    color:          qgcPal.text
    antialiasing:   true

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
}

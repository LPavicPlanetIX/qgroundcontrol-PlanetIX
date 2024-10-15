/****************************************************************************
 *
 * (c) 2009-2022 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls
import QGroundControl.ScreenTools

RowLayout {
    property real fontSize: ScreenTools.defaultFontPointSize

    property alias label:                   _labelLabel.text
    property alias labelText:               _label.text
    property alias labelColor:              _label.color
    property real  labelPreferredWidth:    -1

    spacing: ScreenTools.defaultFontPixelWidth * 2

    QGCLabel { 
        id:                 _labelLabel
        Layout.fillWidth:   true
        fontSizeQGCLabel:   fontSize
    }

    QGCLabel {
        id:                     _label
        Layout.preferredWidth:  labelPreferredWidth
        fontSizeQGCLabel:       fontSize
    }
}


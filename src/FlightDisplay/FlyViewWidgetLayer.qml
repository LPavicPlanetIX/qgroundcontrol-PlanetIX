/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.Vehicle

import MAVLink

// This is the ui overlay layer for the widgets/tools for Fly View
Item {
    id: _root

    property var    parentToolInsets
    property var    totalToolInsets:        _totalToolInsets
    property var    mapControl
    property bool   isViewer3DOpen:         false

    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _planMasterController:  globals.planMasterControllerFlyView
    property var    _missionController:     _planMasterController.missionController
    property var    _geoFenceController:    _planMasterController.geoFenceController
    property var    _rallyPointController:  _planMasterController.rallyPointController
    property var    _guidedController:      globals.guidedControllerFlyView
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property alias  _gripperMenu:           gripperOptions
    property real   _layoutMargin:          ScreenTools.defaultFontPixelWidth * 0.75
    property bool   _layoutSpacing:         ScreenTools.defaultFontPixelWidth
    property bool   _showSingleVehicleUI:   true

    property bool utmspActTrigger

    QGCToolInsets {
        id:                     _totalToolInsets
        leftEdgeTopInset:       toolStrip.leftEdgeTopInset
        leftEdgeCenterInset:    toolStrip.leftEdgeCenterInset
        leftEdgeBottomInset:    virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.leftEdgeBottomInset : parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      topRightColumnLayout.rightEdgeTopInset
        rightEdgeCenterInset:   topRightColumnLayout.rightEdgeCenterInset
        rightEdgeBottomInset:   bottomRightRowLayout.rightEdgeBottomInset
        topEdgeLeftInset:       toolStrip.topEdgeLeftInset
        topEdgeCenterInset:     mapScale.topEdgeCenterInset
        topEdgeRightInset:      topRightColumnLayout.topEdgeRightInset
        bottomEdgeLeftInset:    virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.bottomEdgeLeftInset : parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  bottomRightRowLayout.bottomEdgeCenterInset
        bottomEdgeRightInset:   virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.bottomEdgeRightInset : bottomRightRowLayout.bottomEdgeRightInset
    }

    FlyViewTopRightColumnLayout {
        id:                 topRightColumnLayout
        anchors.margins:    _layoutMargin
        anchors.top:        parent.top
        anchors.bottom:     bottomRightRowLayout.top
        anchors.right:      parent.right
        spacing:            _layoutSpacing

        property real topEdgeRightInset:    childrenRect.height + _layoutMargin
        property real rightEdgeTopInset:    width + _layoutMargin
        property real rightEdgeCenterInset: rightEdgeTopInset
    }

    FlyViewBottomRightRowLayout {
        id:                 bottomRightRowLayout
        anchors.margins:    _layoutMargin
        anchors.bottom:     parent.bottom
        anchors.right:      parent.right
        spacing:            _layoutSpacing

        property real bottomEdgeRightInset:     height + _layoutMargin
        property real bottomEdgeCenterInset:    bottomEdgeRightInset
        property real rightEdgeBottomInset:     width + _layoutMargin
    }

    FlyViewMissionCompleteDialog {
        missionController:      _missionController
        geoFenceController:     _geoFenceController
        rallyPointController:   _rallyPointController
    }

    GuidedActionConfirm {
        anchors.margins:            _toolsMargin
        anchors.top:                parent.top
        anchors.horizontalCenter:   parent.horizontalCenter
        z:                          QGroundControl.zOrderTopMost
        guidedController:           _guidedController
        guidedValueSlider:          _guidedValueSlider
        utmspSliderTrigger:         utmspActTrigger
    }

    //-- Virtual Joystick
    Loader {
        id:                         virtualJoystickMultiTouch
        z:                          QGroundControl.zOrderTopMost + 1
        anchors.right:              parent.right
        anchors.rightMargin:        anchors.leftMargin
        height:                     Math.min(parent.height * 0.25, ScreenTools.defaultFontPixelWidth * 16)
        visible:                    _virtualJoystickEnabled && !QGroundControl.videoManager.fullScreen && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)
        anchors.bottom:             parent.bottom
        anchors.bottomMargin:       bottomLoaderMargin
        anchors.left:               parent.left   
        anchors.leftMargin:         ( y > toolStrip.y + toolStrip.height ? toolStrip.width / 2 : toolStrip.width * 1.05 + toolStrip.x) 
        source:                     "qrc:/qml/VirtualJoystick.qml"
        active:                     _virtualJoystickEnabled && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)

        property real bottomEdgeLeftInset:     parent.height-y
        property bool autoCenterThrottle:      QGroundControl.settingsManager.appSettings.virtualJoystickAutoCenterThrottle.rawValue
        property bool _virtualJoystickEnabled: QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue
        property real bottomEdgeRightInset:    parent.height-y
        property var  _pipViewMargin:          _pipView.visible ? parentToolInsets.bottomEdgeLeftInset + ScreenTools.defaultFontPixelHeight * 2 : 
                                               bottomRightRowLayout.height + ScreenTools.defaultFontPixelHeight * 1.5

        property var  bottomLoaderMargin:      _pipViewMargin >= parent.height / 2 ? parent.height / 2 : _pipViewMargin

        // Width is difficult to access directly hence this hack which may not work in all circumstances
        property real leftEdgeBottomInset:  visible ? bottomEdgeLeftInset + width/18 - ScreenTools.defaultFontPixelHeight*2 : 0
        property real rightEdgeBottomInset: visible ? bottomEdgeRightInset + width/18 - ScreenTools.defaultFontPixelHeight*2 : 0
        property real rootWidth:            _root.width
        property var  itemX:                virtualJoystickMultiTouch.x   // real X on screen

        onRootWidthChanged: virtualJoystickMultiTouch.status == Loader.Ready && visible ? virtualJoystickMultiTouch.item.uiTotalWidth = rootWidth : undefined
        onItemXChanged:     virtualJoystickMultiTouch.status == Loader.Ready && visible ? virtualJoystickMultiTouch.item.uiRealX = itemX : undefined

        //Loader status logic
        onLoaded: {
            if (virtualJoystickMultiTouch.visible) {
                virtualJoystickMultiTouch.item.calibration = true 
                virtualJoystickMultiTouch.item.uiTotalWidth = rootWidth
                virtualJoystickMultiTouch.item.uiRealX = itemX
            } else {
                virtualJoystickMultiTouch.item.calibration = false
            }
        }
    }

    FlyViewToolStrip {
        id:                     toolStrip
        anchors.leftMargin:     _toolsMargin + parentToolInsets.leftEdgeCenterInset
        anchors.topMargin:      _toolsMargin + parentToolInsets.topEdgeLeftInset
        anchors.left:           parent.left
        anchors.top:            parent.top
        z:                      QGroundControl.zOrderWidgets
        maxHeight:              parent.height - y - parentToolInsets.bottomEdgeLeftInset - _toolsMargin
        visible:                !QGroundControl.videoManager.fullScreen

        onDisplayPreFlightChecklist: preFlightChecklistPopup.createObject(mainWindow).open()


        property real topEdgeLeftInset:     visible ? y + height : 0
        property real leftEdgeTopInset:     visible ? x + width : 0
        property real leftEdgeCenterInset:  leftEdgeTopInset
    }

    GripperMenu {
        id: gripperOptions
    }

    VehicleWarnings {
        anchors.centerIn:   parent
        z:                  QGroundControl.zOrderTopMost
    }

    MapScale {
        id:                 mapScale
        anchors.margins:    _toolsMargin
        anchors.left:       toolStrip.right
        anchors.top:        parent.top
        mapControl:         _mapControl
        buttonsOnLeft:      true
        visible:            !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && !isViewer3DOpen && mapControl.pipState.state === mapControl.pipState.fullState

        property real topEdgeCenterInset: visible ? y + height : 0
    }

    Component {
        id: preFlightChecklistPopup
        FlyViewPreFlightChecklistPopup {
        }
    }

    //-- Virtual Terminate Button
    Loader {
        id: virtualTerminateButtonLoader
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: parent.width * 0.025
            topMargin: parent.height * 0.6
        }
        width: parent.width * 0.125
        height: parent.height * 0.125

        source:                     "qrc:/qml/VirtualTerminateButton.qml"
        active:                     _activeVehicle

        onLoaded: {
            if (virtualTerminateButtonLoader.item) {
                virtualTerminateButtonLoader.item.terminateRequest.connect(mainWindow.terminateRequest)
            }
        }
    }

    // Battery Info
    Item {
        id: batteryContentComponent

        anchors {
           right: parent.right
           top: parent.top
           topMargin: parent.height * 0.02
           rightMargin: parent.width * 0.01
        }

        visible: _activeVehicle && _activeVehicle.batteries && _activeVehicle.batteries.count !== 0

        width:  batteryContentComponentColumnLayout.implicitWidth
        height: _activeVehicle && _activeVehicle.batteries
                ? batteryContentComponentColumnLayout.implicitHeight * _activeVehicle.batteries.count
                : 0

        ColumnLayout {
            id: batteryContentComponentColumnLayout

            spacing: ScreenTools.defaultFontPixelHeight / 2

            Component {
                id: batteryValuesAvailableComponent

                QtObject {
                    property bool functionAvailable:         battery.function.rawValue !== MAVLink.MAV_BATTERY_FUNCTION_UNKNOWN
                    property bool showFunction:              functionAvailable && battery.function.rawValue != MAVLink.MAV_BATTERY_FUNCTION_ALL
                    property bool temperatureAvailable:      !isNaN(battery.temperature.rawValue)
                    property bool currentAvailable:          !isNaN(battery.current.rawValue)
                    property bool mahConsumedAvailable:      !isNaN(battery.mahConsumed.rawValue)
                    property bool timeRemainingAvailable:    !isNaN(battery.timeRemaining.rawValue)
                    property bool percentRemainingAvailable: !isNaN(battery.percentRemaining.rawValue)
                    property bool chargeStateAvailable:      battery.chargeState.rawValue !== MAVLink.MAV_BATTERY_CHARGE_STATE_UNDEFINED
                }
            }

            Repeater {
                model: _activeVehicle ? _activeVehicle.batteries : 0

                SettingsGroupLayout {
                    heading:         qsTr("Battery %1").arg(_activeVehicle.batteries.length === 1 ? qsTr("Status") : object.id.rawValue)
                    contentSpacing:  0
                    showDividers:    false
                    layoutColor:     "black"
                    headingFontSize: ScreenTools.defaultFontPointSize * incrementFontIndex

                    property var batteryValuesAvailable: batteryValuesAvailableLoader.item
                    property real incrementFontIndex:    1.15
                    Loader {
                        id:                 batteryValuesAvailableLoader
                        sourceComponent:    batteryValuesAvailableComponent

                        property var battery: object
                    }

                    LabelledLabel {
                        label:      qsTr("Charge State")
                        labelText:  object.chargeState.enumStringValue
                        visible:    batteryValuesAvailable.chargeStateAvailable
                        fontSize:   ScreenTools.defaultFontPointSize * incrementFontIndex
                    }

                    LabelledLabel {
                        label:      qsTr("Remaining")
                        labelText:  object.timeRemainingStr.value
                        visible:    batteryValuesAvailable.timeRemainingAvailable
                        fontSize:   ScreenTools.defaultFontPointSize * incrementFontIndex
                    }

                    LabelledLabel {
                        label:      qsTr("Remaining")
                        labelText:  object.percentRemaining.valueString + " " + object.percentRemaining.units
                        visible:    batteryValuesAvailable.percentRemainingAvailable
                        fontSize: ScreenTools.defaultFontPointSize * incrementFontIndex
                    }

                    LabelledLabel {
                        label:      qsTr("Voltage")
                        labelText:  object.voltage.value.toFixed(1) + " " + object.voltage.units
                        fontSize:   ScreenTools.defaultFontPointSize * incrementFontIndex
                        labelColor: (object.voltage.value < 46) ? "red" : ((object.voltage.value < 47) ? "yellow" : "green")
                    }

                    LabelledLabel {
                        label:     qsTr("Current")
                        labelText: object.current.value.toFixed(1) + " " + object.current.units
                        visible:   batteryValuesAvailable.currentAvailable
                        fontSize:  ScreenTools.defaultFontPointSize * incrementFontIndex
                    }

                    LabelledLabel {
                        label:      qsTr("Consumed")
                        // object.mahConsumed.units is in mAh, and Ah unit is desirable, so divide by 1000
                        labelText:  (object.mahConsumed.value / 1000).toFixed(1) + " " + "Ah"
                        visible:    batteryValuesAvailable.mahConsumedAvailable
                        fontSize:   ScreenTools.defaultFontPointSize * incrementFontIndex
                        labelColor: ((object.mahConsumed.value / 1000) < 15) ? "green" : (((object.mahConsumed.value / 1000) < 18) ? "yellow" : "red")
                    }
                }
            }
        }
    }

    // Message Console
    QGCFlickable {
        id:     scrollableMessageArea
        width:  parent.width / 3
        height: parent.height / 10
        anchors {
            bottom:           parent.bottom
            bottomMargin:     parent.height * 0.01
            horizontalCenter: parent.horizontalCenter
        }
        visible: true

        property var qgcPal:         QGroundControl.globalPalette

        contentWidth:  backgroundOfMessageText.width
        contentHeight: backgroundOfMessageText.height
        clip:          true

        TextArea.flickable: TextArea {
            id:                     messageText
            width:                  parent.width
            height:                 parent.height
            readOnly:               true
            textFormat:             TextEdit.RichText
            color:                  qgcPal.text
            placeholderText:        qsTr("No Messages")
            placeholderTextColor:   qgcPal.text
            padding:                0
            background:             Rectangle {
                                        id: backgroundOfMessageText
                                        width:  scrollableMessageArea.width
                                        height: scrollableMessageArea.height
                                        color:  "black"
                                    }
            visible:                true
            focus:                  true

            property bool _noMessages: messageText.length === 0
            property var  _fact:       null

            function formatMessage(message) {
                message = message.replace(new RegExp("<#E>", "g"), "color: " + qgcPal.warningText + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0)) + "pt monospace;");
                message = message.replace(new RegExp("<#I>", "g"), "color: " + qgcPal.warningText + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0)) + "pt monospace;");
                message = message.replace(new RegExp("<#N>", "g"), "color: " + qgcPal.text + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0)) + "pt monospace;");
                return message;
            }

            Component.onCompleted: {
                if (_activeVehicle && _activeVehicle.formattedMessages) {
                    messageText.text = messageText.formatMessage(_activeVehicle.formattedMessages)
                    _activeVehicle.resetAllMessages()
                }
            }

            Connections {
                target:                 _activeVehicle
                onNewFormattedMessage: (formattedMessage) => { messageText.insert(messageText.length, messageText.formatMessage(formattedMessage)) }
            }

            FactPanelController {
                id: controller
            }

            onLinkActivated: (link) => {
                if (link.startsWith('param://')) {
                    var paramName = link.substr(8);
                    _fact = controller.getParameterFact(-1, paramName, true)
                    if (_fact != null) {
                        paramEditorDialogComponent.createObject(mainWindow).open()
                    }
                } else {
                    Qt.openUrlExternally(link);
                }
            }

            Component {
                id: paramEditorDialogComponent

                ParameterEditorDialog {
                    title:          qsTr("Edit Parameter")
                    fact:           messageText._fact
                    destroyOnClose: true
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top:   parent.top
                width:         ScreenTools.defaultFontPixelHeight * 1.25
                height:        width
                radius:        width / 2
                color:         QGroundControl.globalPalette.button
                border.color:  QGroundControl.globalPalette.buttonText
                visible:       !messageText._noMessages

                QGCColoredImage {
                    anchors.margins:   ScreenTools.defaultFontPixelHeight * 0.25
                    anchors.centerIn:  parent
                    anchors.fill:      parent
                    sourceSize.height: height
                    source:            "/res/TrashDelete.svg"
                    fillMode:          Image.PreserveAspectFit
                    mipmap:            true
                    smooth:            true
                    color:             qgcPal.text
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: {
                        _activeVehicle.clearMessages()
                        messageText.text = ""
                    }
                }
            }
        }
    }

}

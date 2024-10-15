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
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 35
    property alias  _gripperMenu:           gripperOptions
    property real   _layoutMargin:          ScreenTools.defaultFontPixelWidth * 0.75
    property bool   _layoutSpacing:         ScreenTools.defaultFontPixelWidth
    property bool   _showSingleVehicleUI:   true

    property bool utmspActTrigger

    QGCToolInsets {
        id:                     _totalToolInsets
        leftEdgeTopInset:       toolStrip.leftEdgeTopInset
        leftEdgeCenterInset:    toolStrip.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      topRightColumnLayout.rightEdgeTopInset
        rightEdgeCenterInset:   topRightColumnLayout.rightEdgeCenterInset
        rightEdgeBottomInset:   bottomRightRowLayout.rightEdgeBottomInset
        topEdgeLeftInset:       toolStrip.topEdgeLeftInset
        topEdgeCenterInset:     mapScale.topEdgeCenterInset
        topEdgeRightInset:      topRightColumnLayout.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  bottomRightRowLayout.bottomEdgeCenterInset
        bottomEdgeRightInset:   bottomRightRowLayout.bottomEdgeRightInset
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

    // TODO [PlanetIX]: Virtual joystick removed, but
    // virtualJoystickAutoCenterThrottle and virtualJoystick
    // facts in AppSettings.h are still present - need to remove them?

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

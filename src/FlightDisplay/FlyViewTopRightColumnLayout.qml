/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Palette
import QGroundControl.ScreenTools

import MAVLink

ColumnLayout {
    width: _rightPanelWidth
    

    // Battery Info
    Item {
        id: batteryContentComponent
        Layout.alignment:   Qt.AlignTop

        visible: _activeVehicle && _activeVehicle.batteries && _activeVehicle.batteries.count !== 0

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
                    layoutColor:     qgcPal.window
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

    // Flight Info
    Item {
        id: flightContentComponent
        Layout.alignment: Qt.AlignTop

        // activeVehicle.vehicle is fact of the vehicle that contains some data of the vehicle, like airSpeed
        visible: _activeVehicle && _activeVehicle.vehicle !== undefined

        ColumnLayout {
            id: flightContentComponentColumnLayout
            spacing: ScreenTools.defaultFontPixelHeight / 2

            Component {
                id: flightValuesAvailableComponent

                QtObject {
                    property bool airSpeedAvailable: _activeVehicle && _activeVehicle.vehicle ? !isNaN(_activeVehicle.vehicle.airSpeed.rawValue) : false
                    property bool groundSpeedAvailable: _activeVehicle && _activeVehicle.vehicle ? !isNaN(_activeVehicle.vehicle.groundSpeed.rawValue) : false
                }
            }

            SettingsGroupLayout {
                id: flightSettingsGroup

                property real incrementFontIndex:    1.15

                heading: qsTr("Flight Information")
                contentSpacing: 0
                showDividers: false
                layoutColor: qgcPal.window
                headingFontSize: ScreenTools.defaultFontPointSize * incrementFontIndex

                property var flightValuesAvailable

                Loader {
                    id: flightValuesAvailableLoader
                    sourceComponent: flightValuesAvailableComponent
                    onLoaded: {
                        flightSettingsGroup.flightValuesAvailable = flightValuesAvailableLoader.item
                    }
                }

                LabelledLabel {
                    label: qsTr("Airspeed")
                    labelText: _activeVehicle && _activeVehicle.vehicle ? _activeVehicle.vehicle.airSpeed.value.toFixed(1) + " " + _activeVehicle.vehicle.airSpeed.units : "N/A"
                    visible: flightValuesAvailableLoader.status === Loader.Ready 
                            && flightSettingsGroup.flightValuesAvailable
                            && flightSettingsGroup.flightValuesAvailable.airSpeedAvailable
                    fontSize: ScreenTools.defaultFontPointSize * flightSettingsGroup.incrementFontIndex
                    labelColor: _activeVehicle && _activeVehicle.vehicle 
                                ? (_activeVehicle.vehicle.airSpeed.value > 25 || _activeVehicle.vehicle.airSpeed.value <= 18)
                                    ? "red"
                                    : (_activeVehicle.vehicle.airSpeed.value > 23 || _activeVehicle.vehicle.airSpeed.value <= 21)
                                    ? "yellow"
                                    : (_activeVehicle.vehicle.airSpeed.value > 21 && _activeVehicle.vehicle.airSpeed.value <= 23)
                                    ? "green"
                                    : "red"
                                : "red"
                }

                LabelledLabel {
                    label: qsTr("Groundspeed")
                    labelText: _activeVehicle && _activeVehicle.vehicle ? _activeVehicle.vehicle.groundSpeed.value.toFixed(1) + " " + _activeVehicle.vehicle.groundSpeed.units : "N/A"
                    visible: flightValuesAvailableLoader.status === Loader.Ready 
                            && flightSettingsGroup.flightValuesAvailable
                            && flightSettingsGroup.flightValuesAvailable.groundSpeedAvailable
                    fontSize: ScreenTools.defaultFontPointSize * flightSettingsGroup.incrementFontIndex
                }
            }
        }
    }
}

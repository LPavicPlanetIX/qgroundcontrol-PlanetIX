/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "TerminateButton.h"
#include "QGCApplication.h"
#include "QGCToolbox.h"
#include "LinkManager.h"
#include "LinkConfiguration.h"
#include "SerialLink.h"
#include "Vehicle.h"
#include "MultiVehicleManager.h"

TerminateButton::TerminateButton(const std::shared_ptr<SerialLink>& link, QObject* parent)
    : QObject(parent), _link(link) {
        if (_link) {
            connect(_link.get(), &LinkInterface::bytesReceived, this, &TerminateButton::handleSerialData);
        }
}

TerminateButton::~TerminateButton() {
    if (_link) {
        disconnect(_link.get(), &LinkInterface::bytesReceived, this, &TerminateButton::handleSerialData);
    }
}

void TerminateButton::handleSerialData(LinkInterface* link, const QByteArray& data) {
    Q_UNUSED(link);
    if (data.contains("TER1")) {
        emit terminateSignalReceived();
    }
}

/**
 * @todo [lpavic]: On RPi Picco (hardware terminate button) side, checking for
 *                 this functionality is commented out for now since
 *                 Serial.readStringUntil method on RPi Picco side is blocking
 *                 when constantly checking the input serial message - the 
 *                 problem is in huge delay of invocation of flight termination
 *                 when hardware terminate button is being pressed
 */
void TerminateButton::virtualTerminateSignalReceived() {
    QString terminationMessage = "TER1\n";
    QByteArray data = terminationMessage.toUtf8();
    _link->writeBytes(data);
    _link->_hackAccessToPort()->flush();
}

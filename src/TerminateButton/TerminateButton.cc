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
    if (data.contains("TERMINATE")) {
        emit terminateSignalReceived();
    }
}

/**
 * @todo [lpavic]: LED RGB on RPi Terminate Button sometimes does not change color 
 *                 eventhough termination is being called. This happens when virtual
 *                 terminate button confirms termination. Same problem happens when
 *                 terminate button is being disconnected inside Application Settings ->
 *                 Comm Links 
 */
void TerminateButton::virtualTerminateSignalReceived() {
    QString terminationMessage = "TERMINATE\n";
    QByteArray data = terminationMessage.toUtf8();
    _link->writeBytes(data);
    _link->_hackAccessToPort()->flush();
}

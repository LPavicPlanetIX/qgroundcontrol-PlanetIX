/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

/// @file
/// @brief

#pragma once

#include <QtCore/QObject>
#include "LinkConfiguration.h"
#include "SerialLink.h"

/**
 * @todo [lpavic]: When active vehicle is connected along with terminate button, if the
 *                 vehicle is disconnected, terminate buttons should be disconnected as well
 */
class TerminateButton : public QObject
{
    Q_OBJECT
public:
    explicit TerminateButton(const std::shared_ptr<SerialLink>& link, QObject* parent = nullptr);
    ~TerminateButton();

    std::shared_ptr<SerialLink> getLink() const noexcept {
        return _link;
    }

    void virtualTerminateSignalReceived();

private:
    std::shared_ptr<SerialLink> _link {nullptr};

signals:
    void terminateSignalReceived();

private slots:
    void handleSerialData(LinkInterface* link, const QByteArray& data);
};

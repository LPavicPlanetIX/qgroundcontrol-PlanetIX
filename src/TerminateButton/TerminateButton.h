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

class TerminateButton : public QObject
{
    Q_OBJECT
public:
    explicit TerminateButton(QObject* parent = nullptr);
    void setupSerialPort();

    void setLink(const std::shared_ptr<SerialLink>& link) noexcept {
        _link = link;
    }
    std::shared_ptr<SerialLink> getLink() const noexcept {
        return _link;
    }

private:
    std::shared_ptr<SerialLink> _link {nullptr};

signals:
    void terminateSignalReceived();

private slots:
    void handleSerialData(LinkInterface* link, const QByteArray& data);
    void virtualTerminateSignalReceived();
};

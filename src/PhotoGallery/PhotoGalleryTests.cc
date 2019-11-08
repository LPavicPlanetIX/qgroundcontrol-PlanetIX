/****************************************************************************
 *
 *   (c) 2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "AsyncDownloadPhotoTrigger.h"
#include "PhotoFileStore.h"
#include "PhotoGalleryModel.h"

#include <QtTest/QtTest>

#include <fcntl.h>
#include <netinet/ip.h>
#include <poll.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>

#include <iostream>

/* Test helpers. */

namespace {

/// Primitive http server.
///
/// Simple iterative webserver. Turned out to be fastest to just open-code.
class MockHttpServer {
public:
    explicit MockHttpServer(bool run_receiver = true)
        : _run_receiver(run_receiver)
    {
        int pipefds[2];
        if (pipe2(pipefds, O_CLOEXEC) < 0) {
            failStrError("pipe: ");
        }
        _receive_exit_fd = pipefds[0];
        _notify_exit_fd = pipefds[1];

        _listen_fd = ::socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
        if (_listen_fd < 0) {
            failStrError("socket: ");
        }

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        addr.sin_port = htons(0);
        if (::bind(_listen_fd, reinterpret_cast<struct sockaddr *>(&addr),
                   sizeof(addr)) < 0) {
            failStrError("bind: ");
        }
        socklen_t sl = sizeof(addr);
        if (::getsockname(_listen_fd,
                          reinterpret_cast<struct sockaddr *>(&addr),
                          &sl) < 0) {
            failStrError("getsockname: ");
        }
        _port = ntohs(addr.sin_port);
        if (::listen(_listen_fd, 50) < 0) {
            failStrError("listen: ");
        }

        if (_run_receiver) {
            _thread = std::thread([this]() {
                runServer();
            });
        }
    }

    ~MockHttpServer()
    {
        char c = 'X';
        ::write(_notify_exit_fd, &c, sizeof(c));
        if (_run_receiver) {
            _thread.join();
        }
        ::close(_listen_fd);
        ::close(_receive_exit_fd);
        ::close(_notify_exit_fd);
    }

    uint16_t port() const
    {
        return _port;
    }

    QString getBaseURI() const
    {
        return "http://localhost:" + QString::number(port());
    }

    void setResponse(std::string uri, std::string response)
    {
        std::lock_guard<std::mutex> guard(m_lock);
        m_responses.emplace(std::move(uri), std::move(response));
    }

    std::vector<std::string> getAndClearSeenRequestURIs()
    {
        std::lock_guard<std::mutex> guard(m_lock);
        return std::move(m_seen_request_uris);
    }

private:
    static void failStrError(const char * prefix)
    {
        QFAIL((prefix + std::string(strerror(errno))).c_str());
    }

    void runServer()
    {
        for (;;) {
            struct pollfd pfds[2];
            pfds[0].fd = _receive_exit_fd;
            pfds[0].events = POLLIN;
            pfds[1].fd = _listen_fd;
            pfds[1].events = POLLIN;
            ::poll(pfds, 2, -1);
            if ((pfds[0].revents & POLLIN) == POLLIN) {
                break;
            }
            if ((pfds[1].revents & POLLIN) == POLLIN) {
                handleConnection();
            }
        }
    }

    void handleConnection()
    {
        int fd = ::accept4(_listen_fd, nullptr, 0, SOCK_CLOEXEC);
        if (fd < 0) {
            failStrError("accept: ");
        }

        handleConnectionData(fd);

        ::close(fd);
    }

    void handleConnectionData(int fd)
    {
        std::vector<char> buffer;
        for (;;) {
            if (std::find(buffer.begin(), buffer.end(), '\r') != buffer.end()) {
                break;
            }
            size_t current_size = buffer.size();
            buffer.resize(current_size + 1024);
            ssize_t count = ::recv(fd, &buffer[current_size], 1024,
                                   MSG_NOSIGNAL);
            if (count <= 0) {
                return;
            }
            buffer.resize(current_size + count);
        }

        auto endl = std::find(buffer.begin(), buffer.end(), '\r');
        auto space1 = std::find(buffer.begin(), endl, ' ');
        if (space1 == endl) {
            return;
        }

        auto space2 = std::find(std::next(space1), endl, ' ');
        if (space2 == endl) {
            return;
        }
        std::string method(buffer.begin(), space1);
        std::string uri(std::next(space1), space2);

        std::string response;
        if (method == "GET") {
            std::lock_guard<std::mutex> guard(m_lock);
            response = generateResponse(uri);
            m_seen_request_uris.push_back(uri);
        } else {
            response = "HTTP/1.0 400 Bad request\r\nServer: localhost\r\n\r\n";
        }

        std::size_t sent = 0;
        while (sent < response.size()) {
            ssize_t count = ::send(fd, &response[sent], response.size() - sent,
                                   MSG_NOSIGNAL);
            if (count <= 0) {
                return;
            }
            sent += count;
        }
    }

    std::string generateResponse(const std::string & uri)
    {
        auto i = m_responses.find(uri);
        return i == m_responses.end()
               ? std::string("HTTP/1.0 404 Not found\r\n"
                             "Server: localhost\r\n"
                             "\r\n")
               : i->second;
    }

    int _listen_fd;
    int _notify_exit_fd;
    int _receive_exit_fd;
    uint16_t _port;
    bool _run_receiver;
    std::thread _thread;
    std::mutex m_lock;
    std::map<std::string, std::string> m_responses;
    std::vector<std::string> m_seen_request_uris;
};

QByteArray createJPEGImageByteArray(int width, int height)
{
    QImage image(width, height, QImage::Format_ARGB32);
    QByteArray ba;
    QBuffer buffer(&ba);
    buffer.open(QIODevice::WriteOnly);
    image.save(&buffer, "JPEG");
    return ba;
}

std::string createJPEGImage(int width, int height)
{
    QByteArray ba = createJPEGImageByteArray(width, height);
    return std::string(ba.begin(), ba.end());
}

void verifyImage(const QImage & image, int width, int height)
{
    QCOMPARE(image.width(), width);
    QCOMPARE(image.height(), height);
}

void verifyImage(const PhotoFileStore & store, const QString & id,
                    int width, int height)
{
    auto data = store.read(id);
    QVERIFY(data.canConvert<QByteArray>());
    QImage image = QImage::fromData(data.value<QByteArray>());
    verifyImage(image, width, height);
}

void
setFileContents(const QString & path, const QByteArray & contents)
{
    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadWrite | QIODevice::NewOnly));
    QCOMPARE(contents.size(), file.write(contents));
    file.close();
}

void
verifyFileContents(const QString & path, const QByteArray & contents)
{
    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadOnly));
    auto data = file.readAll();
    QCOMPARE(data, contents);
    file.close();
}

void
verifyFileMissing(const QString & path)
{
    QFile file(path);
    QVERIFY(!file.open(QIODevice::ReadOnly));
}

}  // namespace

/* Actual tests. */

class PhotoGalleryTests : public QObject {
    Q_OBJECT

private slots:
    void testPhotoFileStoreFilesystem();
    void testPhotoFileStoreNameCollisions();
    void testPhotoFileStoreInitNotifications();
    void testPhotoFileStoreRuntimeNotifications();
    void testPhotoTriggerDownloadSuccess();
    void testPhotoTriggerAbortEarly();
    void testPhotoTriggerDownloadFail();
    void testPhotoTriggerDownloadTimeout();
    void testPhotoUnsolicitedDownload();
    void testPhotoGalleryModel();
};

/// Verify photo store interacts correctly with filesystem.
void PhotoGalleryTests::testPhotoFileStoreFilesystem()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());

    setFileContents(temp_dir.filePath("foo.jpg"), "foo_content");
    setFileContents(temp_dir.filePath("bar.jpg"), "bar_content");
    PhotoFileStore store(temp_dir.path());

    QCOMPARE(std::set<QString>({"bar.jpg", "foo.jpg"}), store.ids());

    auto c = store.read("bar.jpg");
    QVERIFY(c.canConvert<QByteArray>());
    QCOMPARE(c.value<QByteArray>(), "bar_content");

    auto id = store.add("baz.jpg", "baz_content");
    QCOMPARE(id, "baz.jpg");
    QCOMPARE(std::set<QString>({"bar.jpg", "baz.jpg", "foo.jpg"}), store.ids());

    store.remove({"foo.jpg"});
    QCOMPARE(std::set<QString>({"bar.jpg", "baz.jpg"}), store.ids());
    verifyFileContents(temp_dir.filePath("bar.jpg"), "bar_content");
    verifyFileContents(temp_dir.filePath("baz.jpg"), "baz_content");
    verifyFileMissing(temp_dir.filePath("foo.jpg"));
}

/// Verify that names are kept if possible, but collisions are resolved.
void PhotoGalleryTests::testPhotoFileStoreNameCollisions()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());

    PhotoFileStore store(temp_dir.path());

    auto foo_jpg = store.add("foo.jpg", "foo1");
    QCOMPARE(foo_jpg, "foo.jpg");
    auto foo2_jpg = store.add("foo.jpg", "foo2");
    QVERIFY(foo2_jpg != foo_jpg);

    QCOMPARE(std::set<QString>({foo_jpg, foo2_jpg}), store.ids());
    QVERIFY(QRegularExpression("^.*\\.jpg$").match(foo2_jpg).hasMatch());
    verifyFileContents(temp_dir.filePath(foo2_jpg), "foo2");
}

/// Verify observer is modified when store path is reconfigured.
///
/// This situation arises in the main program as the correct path is configured
/// at runtime, after all models and views have been instantiated already.
void PhotoGalleryTests::testPhotoFileStoreInitNotifications()
{
    PhotoFileStore store;

    std::set<QString> added;
    QObject::connect(
        &store, &PhotoFileStore::added,
        [&added](const std::set<QString> & ids) {
            added.insert(ids.begin(), ids.end());
        });
    QCOMPARE(std::set<QString>(), added);

    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());

    setFileContents(temp_dir.filePath("foo.jpg"), "foo_content");
    setFileContents(temp_dir.filePath("bar.jpg"), "bar_content");

    store.setLocation(temp_dir.path());
    QCOMPARE(std::set<QString>({"bar.jpg", "foo.jpg"}), store.ids());
}

/// Verify that notifications are sent when changing store.
void PhotoGalleryTests::testPhotoFileStoreRuntimeNotifications()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());

    PhotoFileStore store(temp_dir.path());
    std::set<QString> added;
    std::set<QString> removed;
    QObject::connect(
        &store, &PhotoFileStore::added,
        [&added](const std::set<QString> & ids) {
            added.insert(ids.begin(), ids.end());
        });
    QObject::connect(
        &store, &PhotoFileStore::removed,
        [&removed](const std::set<QString> & ids) {
            removed.insert(ids.begin(), ids.end());
        });

    store.add("foo.jpg", "xxx");
    QCOMPARE(std::set<QString>({"foo.jpg"}), added);
    QCOMPARE(std::set<QString>(), removed);
    added.clear();

    store.remove({"foo.jpg"});
    QCOMPARE(std::set<QString>(), added);
    QCOMPARE(std::set<QString>({"foo.jpg"}), removed);
}

/// Verify complete workflow of taking photo.
///
/// - Triggers taking a photo.
/// - Downloads photo from source.
/// - Puts it into store.
/// - Verify that correct signals are emitted at every step.
void PhotoGalleryTests::testPhotoTriggerDownloadSuccess()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());
    PhotoFileStore store(temp_dir.path());

    MockHttpServer http;
    http.setResponse(
        "/foo.jpg", "HTTP/1.0 200 Ok\r\n"
        "Content-Type: image/jpeg\r\n"
        "\r\n" +
        createJPEGImage(16, 16));

    bool photo_triggered = false;

    AsyncDownloadPhotoTrigger photo_trigger(
        [&photo_triggered](){photo_triggered = true; return true; },
        {},
        &store);

    auto op = photo_trigger.takePhoto();
    QVERIFY(photo_triggered);
    QVERIFY(!op->finished());

    bool notified_completion = false;
    QObject::connect(
        op, &AbstractPhotoTriggerOperation::finish,
        [&notified_completion, op]() {
            notified_completion = true;
            QVERIFY(op->finished());
            QVERIFY(op->success());
            QCOMPARE(op->id(), "foo.jpg");
        });

    photo_trigger.completePhotoWithURI(http.getBaseURI() + "/foo.jpg");
    while (!notified_completion) {
        QTest::qWait(10);
    }

    verifyImage(store, "foo.jpg", 16, 16);
}

/// Verify that taking photo can be rejected by backend
///
/// Triggers taking a photo, reports failure.
void PhotoGalleryTests::testPhotoTriggerAbortEarly()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());
    PhotoFileStore store(temp_dir.path());

    AsyncDownloadPhotoTrigger photo_trigger(
        [](){ return false; },
        {},
        &store);

    auto op = photo_trigger.takePhoto();
    QVERIFY(!op);
}

/// Verify workflow of taking photo, but failing download
///
/// - Triggers taking a photo.
/// - Start download, but fails it.
void PhotoGalleryTests::testPhotoTriggerDownloadFail()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());
    PhotoFileStore store(temp_dir.path());

    MockHttpServer http;
    bool photo_triggered = false;

    AsyncDownloadPhotoTrigger photo_trigger(
        [&photo_triggered](){photo_triggered = true; return true; },
        {},
        &store);

    auto op = photo_trigger.takePhoto();
    QVERIFY(photo_triggered);
    QVERIFY(!op->finished());

    bool notified_completion = false;
    QObject::connect(
        op, &AbstractPhotoTriggerOperation::finish,
        [&notified_completion, op]() {
            notified_completion = true;
            QVERIFY(op->finished());
            QVERIFY(!op->success());
        });

    photo_trigger.completePhotoWithURI(http.getBaseURI() + "/foo.jpg");
    while (!notified_completion) {
        QTest::qWait(10);
    }
}

/// Verify wokflow of taking photo, but running into timeout during download
///
/// - Triggers taking a photo.
/// - Start download, but time out tho download
void PhotoGalleryTests::testPhotoTriggerDownloadTimeout()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());
    PhotoFileStore store(temp_dir.path());

    // Set up server, but do not start receiver thread. The http server can
    // be connected to, but it will never respond. Any attempt to download a
    // photo will therefore simply "hang" indefinitely.
    MockHttpServer http(false);
    bool photo_triggered = false;

    // Set a short timeout to avoid hanging unit test for long.
    AsyncDownloadPhotoTrigger photo_trigger(
        [&photo_triggered](){photo_triggered = true; return true; },
        {std::chrono::milliseconds(10)},
        &store);

    auto op = photo_trigger.takePhoto();
    QVERIFY(photo_triggered);
    QVERIFY(!op->finished());

    bool notified_completion = false;
    QObject::connect(
        op, &AbstractPhotoTriggerOperation::finish,
        [&notified_completion, op]() {
            notified_completion = true;
            QVERIFY(op->finished());
            QVERIFY(!op->success());
        });

    photo_trigger.completePhotoWithURI(http.getBaseURI() + "/foo.jpg");
    // It would be nice to verify that the code has initiated a connection
    // to the http server at this point.
    while (!notified_completion) {
        QTest::qWait(10);
    }
}

/// Verify that "unsolicited" photos are still processed.
///
/// - Receive notification that photo has been taken (without having requested
///   it before).
/// - Downloads photo from source.
/// - Puts it into store.
/// - Verify that correct signals are emitted at every step.
void PhotoGalleryTests::testPhotoUnsolicitedDownload()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());
    PhotoFileStore store(temp_dir.path());

    MockHttpServer http;
    http.setResponse(
        "/foo.jpg", "HTTP/1.0 200 Ok\r\n"
        "Content-Type: image/jpeg\r\n"
        "\r\n" +
        createJPEGImage(16, 16));

    bool photo_triggered = false;

    AsyncDownloadPhotoTrigger photo_trigger(
        [&photo_triggered](){photo_triggered = true; return true; },
        {},
        &store);

    std::set<QString> added;
    QObject::connect(
        &store, &PhotoFileStore::added,
        [&added](const std::set<QString> & ids) {
            added.insert(ids.begin(), ids.end());
        });

    photo_trigger.completePhotoWithURI(http.getBaseURI() + "/foo.jpg");
    while (added.empty()) {
        QTest::qWait(10);
    }

    verifyImage(store, "foo.jpg", 16, 16);
}

void PhotoGalleryTests::testPhotoGalleryModel()
{
    QTemporaryDir temp_dir;
    QVERIFY(temp_dir.isValid());

    setFileContents(temp_dir.filePath("2019-09-01.jpg"), createJPEGImageByteArray(16, 16));
    setFileContents(temp_dir.filePath("2019-09-02.jpg"), createJPEGImageByteArray(17, 17));

    PhotoFileStore store;
    PhotoGalleryModel model(&store);

    using index_set_t = std::set<PhotoGalleryModelIndex>;
    index_set_t added, removed;
    QObject::connect(
        &model, &PhotoGalleryModel::added,
        [&added](const index_set_t & indices) {
            added = indices;
        });
    QObject::connect(
        &model, &PhotoGalleryModel::removed,
        [&removed](const index_set_t & indices) {
            removed = indices;
        });

    store.setLocation(temp_dir.path());
    QCOMPARE(added, (index_set_t{0, 1}));
    QCOMPARE(removed, (index_set_t{}));

    auto id4 = store.add("2019-09-04.jpg", createJPEGImageByteArray(15, 15));
    QCOMPARE(added, (index_set_t{2}));

    auto id3 = store.add("2019-09-03.jpg", createJPEGImageByteArray(14, 14));
    QCOMPARE(added, (index_set_t{2}));

    store.remove({"2019-09-02.jpg"});
    QCOMPARE(removed, (index_set_t{1}));

    auto pic0 = model.data(0);
    QCOMPARE(pic0.id, "2019-09-01.jpg");
    verifyImage(*pic0.image, 16, 16);

    auto pic1 = model.data(1);
    QCOMPARE(pic1.id, "2019-09-03.jpg");
    verifyImage(*pic1.image, 14, 14);

    auto pic2 = model.data(2);
    QCOMPARE(pic2.id, "2019-09-04.jpg");
    verifyImage(*pic2.image, 15, 15);
}

QTEST_MAIN(PhotoGalleryTests)
#include "PhotoGalleryTests.moc"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "inventory_manager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("Smart Resource Manager");

    inventory_manager manager;
    if (!manager.database_setup_in_inventory()) {
        qDebug() << "Database initialization failed.";
        return -1;
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("inventory_backend", &manager);

    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}

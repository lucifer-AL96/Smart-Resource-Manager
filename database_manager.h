#ifndef DATABASE_MANAGER_H
#define DATABASE_MANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>

class database_manager : public QObject
{
    Q_OBJECT

public:
    explicit database_manager(QObject *parent = nullptr);
    ~database_manager();

    bool database_setup();
    QVariantList execute_query(const QString &sql_query_str, const QVariantMap &binding_values_variant_map);
    bool execute_non_query(const QString &sql_query_str, const QVariantMap &binding_values_variant_map);

private:
    QSqlDatabase srm_db;
    bool create_tables();
};

#endif // DATABASE_MANAGER_H

#include "database_manager.h"
#include <QSqlRecord>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QVariantMap>
#include <QVariantList>
#include <QDir>
#include <QDateTime>

database_manager::database_manager(QObject *parent)
    : QObject(parent)
{
}

database_manager::~database_manager()
{
    if (srm_db.isOpen())
    {
        srm_db.close();
    }
}

bool database_manager::database_setup()
{
    qDebug() << "START: database_setup() ";

    QString db_path = QDir::currentPath() + "/SRM.db";
    srm_db = QSqlDatabase::addDatabase("QSQLITE");
    srm_db.setDatabaseName(db_path);

    if (!srm_db.open())
    {
        qDebug() << "END: database_setup() with Error opening SQLite database:" << srm_db.lastError().text();
        return false;
    }

    QSqlQuery pragma(srm_db);
    pragma.exec("PRAGMA foreign_keys = ON");

    qDebug() << "END: database_setup() ";
    return create_tables();
}

bool database_manager::create_tables()
{
    qDebug() << "START: create_tables() ";

    QSqlQuery create_table_query;

    QString create_assets_table =
        "CREATE TABLE IF NOT EXISTS assets ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  asset_name TEXT NOT NULL,"
        "  asset_category TEXT NOT NULL,"
        "  total_quantity INTEGER NOT NULL DEFAULT 1,"
        "  asset_brand TEXT,"
        "  asset_model TEXT,"
        "  serial_number TEXT,"
        "  asset_specs TEXT,"
        "  notes TEXT,"
        "  created_at TEXT,"
        "  last_updated TEXT"
        ")";

    if (!create_table_query.exec(create_assets_table)) {
        qDebug() << "END: create_tables() with Failed to create 'assets' table:" << create_table_query.lastError().text();
        return false;
    }

    QString create_units_table =
        "CREATE TABLE IF NOT EXISTS asset_units ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  asset_unit_id TEXT NOT NULL UNIQUE,"
        "  asset_ref_id INTEGER NOT NULL,"
        "  assigned_to TEXT NOT NULL,"
        "  asset_location TEXT NOT NULL,"
        "  status TEXT DEFAULT 'Active',"
        "  assigned_date TEXT,"
        "  return_date TEXT,"
        "  notes TEXT,"
        "  last_updated TEXT,"
        "  FOREIGN KEY (asset_ref_id) REFERENCES assets(id) ON DELETE CASCADE"
        ")";

    if (!create_table_query.exec(create_units_table))
    {
        qDebug() << "END: create_tables() with Failed to create 'asset_units' table:" << create_table_query.lastError().text();
        return false;
    }

    qDebug() << "END: create_tables() ";
    return true;
}

QVariantList database_manager::execute_query(const QString &sql_query_str, const QVariantMap &binding_values_variant_map)
{
    qDebug() << "START: execute_query()";
    qDebug() << "SQL Query:" << sql_query_str;
    qDebug() << "Binding values:" << binding_values_variant_map;

    QVariantList variant_map_results;
    QSqlQuery execute_query;

    if (!execute_query.prepare(sql_query_str))
    {
        qDebug() << "ERROR: Failed to prepare query:" << execute_query.lastError().text();
        return variant_map_results;
    }

    for (auto ii = binding_values_variant_map.begin(); ii != binding_values_variant_map.end(); ++ii)
    {
        execute_query.bindValue(ii.key(), ii.value());
        qDebug() << "Bound" << ii.key() << "=" << ii.value();
    }

    if (!execute_query.exec())
    {
        qDebug() << "ERROR: SQL query execution failed:" << execute_query.lastError().text();
        return variant_map_results;
    }

    QSqlRecord record = execute_query.record();
    qDebug() << "Available fields:" << record.count();

    for (int i = 0; i < record.count(); ++i)
    {
        qDebug() << "Field" << i << ":" << record.fieldName(i);
    }

    while (execute_query.next())
    {
        QVariantMap variant_map_row;

        for (int i = 0; i < record.count(); ++i)
        {
            QString fieldName = record.fieldName(i);
            QVariant fieldValue = execute_query.value(i);
            variant_map_row[fieldName] = fieldValue;
        }

        variant_map_results.append(variant_map_row);
    }

    qDebug() << "END: execute_query() - Retrieved" << variant_map_results.count() << "rows";
    return variant_map_results;
}

bool database_manager::execute_non_query(const QString &sql_query_str, const QVariantMap &binding_values_variant_map)
{
    qDebug() << "START: execute_non_query() ";
    QSqlQuery execute_non_query;
    execute_non_query.prepare(sql_query_str);

    for (auto it = binding_values_variant_map.begin(); it != binding_values_variant_map.end(); ++it) {
        execute_non_query.bindValue(it.key(), it.value());
    }

    if (!execute_non_query.exec()) {
        qDebug() << "END: execute_non_query() with SQL write operation failed:" << execute_non_query.lastError().text();
        return false;
    }

    qDebug() << "END: execute_non_query() ";

    return true;
}

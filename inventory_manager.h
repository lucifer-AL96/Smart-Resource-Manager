#ifndef INVENTORY_MANAGER_H
#define INVENTORY_MANAGER_H
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include "database_manager.h"

class inventory_manager : public QObject
{
    Q_OBJECT
public:
    explicit inventory_manager(QObject *parent = nullptr);
    ~inventory_manager();

    Q_INVOKABLE bool database_setup_in_inventory();

    // ===== ASSETS (master catalog) =====
    Q_INVOKABLE bool         add_asset(const QVariantMap &data);
    Q_INVOKABLE bool         update_asset(int id, const QVariantMap &data);
    Q_INVOKABLE bool         delete_asset(int id);
    Q_INVOKABLE QVariantList get_all_assets();
    Q_INVOKABLE QVariantList searched_assets(const QString &search, const QString &category);
    Q_INVOKABLE QVariantList get_sorted_assets(const QString &field, bool ascending,
                                               const QString &category, const QString &search);

    // ==== ASSET UNITS (assignment tracker) ====
    Q_INVOKABLE bool         assign_unit(const QVariantMap &data);
    Q_INVOKABLE bool         update_unit(int unitId, const QVariantMap &data);
    Q_INVOKABLE bool         return_unit(int unitId);
    Q_INVOKABLE bool         delete_unit(int unitId);
    Q_INVOKABLE QVariantList search_units_by_person(const QString &name);
    Q_INVOKABLE QVariantList get_units_for_asset(int assetRefId);
    Q_INVOKABLE QVariantList get_all_units();

    // ==== STATS ====
    Q_INVOKABLE QVariantMap  get_inventory_statistics();

    //=== EXPORT REPORT ===
    Q_INVOKABLE bool export_report(const QUrl &destination);

signals:
    void inventory_changed();

private:
    database_manager obj_db_manager;
    QString generate_asset_unit_id(const QString &category);
    int     get_pending_count(int asset_ref_id);
};
#endif // INVENTORY_MANAGER_H

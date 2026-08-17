#include "inventory_manager.h"
#include <QDateTime>
#include <QDebug>
#include <QRandomGenerator>
#include <QFile>
#include <QTextStream>
#include <QUrl>

inventory_manager::inventory_manager(QObject *parent)
    : QObject(parent), obj_db_manager(this)
{
}

inventory_manager::~inventory_manager()
{
}

bool inventory_manager::database_setup_in_inventory()
{
    return obj_db_manager.database_setup();
}

QString inventory_manager::generate_asset_unit_id(const QString &category)
{
    QString prefix = "GEN";

    if      (category == "Laptop")
    {
        prefix = "LAP";
    }
    else if (category == "Desktop")
    {
        prefix = "DSK";
    }
    else if (category == "Storage")
    {
        prefix = "STR";
    }
    else if (category == "Printer")
    {
        prefix = "PRT";
    }
    else if (category == "Network")
    {
        prefix = "NET";
    }
    else if (category.length() >= 3)
    {
        prefix = category.left(3).toUpper();
    }

    int digits = QRandomGenerator::global()->bounded(1000, 10000);

    const QString letters = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    QString suffix;
    for (int i = 0; i < 3; i++)
        suffix += letters[QRandomGenerator::global()->bounded(letters.length())];

    return prefix + "-" + QString::number(digits) + "-" + suffix;
}

// ============ ASSETS - MASTER CATALOG =================

bool inventory_manager::add_asset(const QVariantMap &data)
{
    qDebug() << "START: add_asset() ";

    QString str_add_asset_query =
        "INSERT INTO assets "
        "(asset_name, asset_category, total_quantity, asset_brand, asset_model, "
        " serial_number, asset_specs, notes, created_at) "
        "VALUES "
        "(:asset_name, :asset_category, :total_quantity, :asset_brand, :asset_model, "
        " :serial_number, :asset_specs, :notes, :created_at)";

    QString create_date_str = QDateTime::currentDateTime().toString("dd-MM-yyyy hh:mm AP");

    QVariantMap add_asset_map;
    add_asset_map[":asset_name"]     = data["asset_name"].toString();
    add_asset_map[":asset_category"] = data["asset_category"].toString();
    add_asset_map[":total_quantity"] = data["total_quantity"].toInt();
    add_asset_map[":asset_brand"]    = data["asset_brand"].toString();
    add_asset_map[":asset_model"]    = data["asset_model"].toString();
    add_asset_map[":serial_number"]  = data["serial_number"].toString();
    add_asset_map[":asset_specs"]    = data["asset_specs"].toString();
    add_asset_map[":notes"]          = data["notes"].toString();
    add_asset_map[":created_at"]     = create_date_str;

    bool is_add_asset_query_run = obj_db_manager.execute_non_query(str_add_asset_query, add_asset_map);
    if (is_add_asset_query_run)
    {
        qDebug() << "Asset added successfully.";
        emit inventory_changed();
    }
    else
    {
        qDebug() << "Failed to add asset";
    }

    qDebug() << "END: add_asset() ";
    return is_add_asset_query_run;
}

bool inventory_manager::update_asset(int id, const QVariantMap &data)
{
    qDebug() << "START: update_asset() ";

    QString str_update_query =
        "UPDATE assets SET "
        "asset_name=:asset_name, "
        "asset_category=:asset_category, "
        "total_quantity=:total_quantity, "
        "asset_brand=:asset_brand, "
        "asset_model=:asset_model, "
        "serial_number=:serial_number, "
        "asset_specs=:asset_specs, "
        "notes=:notes, "
        "last_updated=:last_updated "
        "WHERE id=:id";

    QVariantMap update_map;
    update_map[":id"]             = id;
    update_map[":asset_name"]     = data["asset_name"].toString();
    update_map[":asset_category"] = data["asset_category"].toString();
    update_map[":total_quantity"] = data["total_quantity"].toInt();
    update_map[":asset_brand"]    = data["asset_brand"].toString();
    update_map[":asset_model"]    = data["asset_model"].toString();
    update_map[":serial_number"]  = data["serial_number"].toString();
    update_map[":asset_specs"]    = data["asset_specs"].toString();
    update_map[":notes"]          = data["notes"].toString();
    update_map[":last_updated"]   = QDateTime::currentDateTime().toString("dd-MM-yyyy hh:mm AP");

    bool is_update_query_run = obj_db_manager.execute_non_query(str_update_query, update_map);
    if (is_update_query_run)
    {
        qDebug() << "Asset" << id << "updated successfully.";
        emit inventory_changed();
    }

    qDebug() << "END: update_asset() ";
    return is_update_query_run;
}

bool inventory_manager::delete_asset(int id)
{
    qDebug() << "START: delete_asset() ";

    QVariantMap delete_map;
    delete_map[":id"] = id;
    obj_db_manager.execute_non_query("DELETE FROM asset_units WHERE asset_ref_id = :id", delete_map);

    bool is_delete_query_run = obj_db_manager.execute_non_query("DELETE FROM assets WHERE id = :id", delete_map);
    if (is_delete_query_run)
    {
        qDebug() << "Asset" << id << "and its units deleted successfully.";
        emit inventory_changed();
    }

    qDebug() << "END: delete_asset() ";
    return is_delete_query_run;
}

QVariantList inventory_manager::searched_assets(const QString &search, const QString &category)
{
    qDebug() << "START: searched_assets() ";

    QString str_search_query =
        "SELECT a.*, "
        "  COUNT(CASE WHEN u.status != 'Inactive' THEN 1 END) AS assigned_quantity, "
        "  (a.total_quantity - COUNT(CASE WHEN u.status != 'Inactive' THEN 1 END)) AS pending_quantity "
        "FROM assets a "
        "LEFT JOIN asset_units u ON u.asset_ref_id = a.id "
        "WHERE 1=1";

    QVariantMap search_map;

    if (!search.isEmpty())
    {
        str_search_query += " AND (a.asset_name LIKE :search OR a.asset_brand LIKE :search "
                            "OR a.asset_model LIKE :search OR a.serial_number LIKE :search)";
        search_map[":search"] = "%" + search + "%";
    }

    if (!category.isEmpty() && category != "All")
    {
        str_search_query += " AND a.asset_category = :category";
        search_map[":category"] = category;
    }

    str_search_query += " GROUP BY a.id ORDER BY a.id ASC";

    qDebug() << "END: searched_assets() ";
    return obj_db_manager.execute_query(str_search_query, search_map);
}

QVariantList inventory_manager::get_all_assets()
{
    return searched_assets("", "All");
}

QVariantList inventory_manager::get_sorted_assets(const QString &field, bool ascending,
                                                  const QString &category, const QString &search)
{
    QVariantList searched_assets_list = searched_assets(search, category);

    static const QStringList quantity_fields = { "total_quantity", "assigned_quantity", "pending_quantity" };

    std::sort(searched_assets_list.begin(), searched_assets_list.end(), [&](const QVariant &a, const QVariant &b)
              {
                  QVariantMap map_a = a.toMap();
                  QVariantMap map_b = b.toMap();

                  if (quantity_fields.contains(field))
                  {
                      int va = map_a[field].toInt();
                      int vb = map_b[field].toInt();
                      return ascending ? va < vb : va > vb;
                  }

                  QString va = map_a[field].toString().toLower();
                  QString vb = map_b[field].toString().toLower();
                  return ascending ? va < vb : va > vb;
              });

    return searched_assets_list;
}

//================= ASSET UNITS — ASSIGNMENT TRACKER ================

int inventory_manager::get_pending_count(int asset_ref_id)
{
    QString str_pending_query =
        "SELECT "
        "  (a.total_quantity - COUNT(CASE WHEN u.status != 'Inactive' THEN 1 END)) AS pending "
        "FROM assets a "
        "LEFT JOIN asset_units u ON u.asset_ref_id = a.id "
        "WHERE a.id = :id "
        "GROUP BY a.id";

    QVariantMap map_id;
    map_id[":id"] = asset_ref_id;

    QVariantList result = obj_db_manager.execute_query(str_pending_query, map_id);
    if (result.isEmpty()) return 0;
    return result.first().toMap()["pending"].toInt();
}

bool inventory_manager::assign_unit(const QVariantMap &data)
{
    qDebug() << "START: assign_unit() ";

    int asset_ref_id = data["asset_ref_id"].toInt();

    // Check availability
    int pending = get_pending_count(asset_ref_id);
    if (pending <= 0)
    {
        qDebug() << "END: assign_unit() — no pending units available for asset" << asset_ref_id;
        return false;
    }

    // Get category for id prefix
    QVariantMap category_map;
    category_map[":id"] = asset_ref_id;
    QVariantList category_result_map = obj_db_manager.execute_query(
        "SELECT asset_category FROM assets WHERE id = :id", category_map);

    if (category_result_map.isEmpty())
    {
        qDebug() << "END: assign_unit() — asset not found:" << asset_ref_id;
        return false;
    }
    QString category = category_result_map.first().toMap()["asset_category"].toString();

    // Generate unique unit ID (retry on rare collision)
    QString unit_id;
    bool unique = false;
    for (int attempt = 0; attempt < 10 && !unique; attempt++)
    {
        unit_id = generate_asset_unit_id(category);
        QVariantMap check_uid_map;
        check_uid_map[":uid"] = unit_id;
        QVariantList existing = obj_db_manager.execute_query(
            "SELECT id FROM asset_units WHERE asset_unit_id = :uid", check_uid_map);
        unique = existing.isEmpty();
    }

    QString current_timestemp = QDateTime::currentDateTime().toString("dd-MM-yyyy hh:mm AP");

    QString str_insert_query =
        "INSERT INTO asset_units "
        "(asset_unit_id, asset_ref_id, assigned_to, asset_location, status, "
        " assigned_date, return_date, notes, last_updated) "
        "VALUES "
        "(:asset_unit_id, :asset_ref_id, :assigned_to, :asset_location, :status, "
        " :assigned_date, :return_date, :notes, :last_updated)";

    QVariantMap assigned_unit_map;
    assigned_unit_map[":asset_unit_id"]  = unit_id;
    assigned_unit_map[":asset_ref_id"]   = asset_ref_id;
    assigned_unit_map[":assigned_to"]    = data["assigned_to"].toString();
    assigned_unit_map[":asset_location"] = data["asset_location"].toString();
    assigned_unit_map[":status"]         = data["status"].toString().isEmpty() ? "Active" : data["status"].toString();
    assigned_unit_map[":assigned_date"]  = current_timestemp;
    assigned_unit_map[":return_date"]    = "";
    assigned_unit_map[":notes"]          = data["notes"].toString();
    assigned_unit_map[":last_updated"]   = current_timestemp;

    bool is_assigned_query_run = obj_db_manager.execute_non_query(str_insert_query, assigned_unit_map);
    if (is_assigned_query_run)
    {
        qDebug() << "Unit" << unit_id << "assigned successfully.";
        emit inventory_changed();
    }

    qDebug() << "END: assign_unit() ";
    return is_assigned_query_run;
}

bool inventory_manager::update_unit(int unitId, const QVariantMap &data)
{
    qDebug() << "START: update_unit() ";

    QString str_update_query =
        "UPDATE asset_units SET "
        "assigned_to=:assigned_to, "
        "asset_location=:asset_location, "
        "status=:status, "
        "notes=:notes, "
        "last_updated=:last_updated "
        "WHERE id=:id";

    QVariantMap update_assigned_map;
    update_assigned_map[":id"]             = unitId;
    update_assigned_map[":assigned_to"]    = data["assigned_to"].toString();
    update_assigned_map[":asset_location"] = data["asset_location"].toString();
    update_assigned_map[":status"]         = data["status"].toString();
    update_assigned_map[":notes"]          = data["notes"].toString();
    update_assigned_map[":last_updated"]   = QDateTime::currentDateTime().toString("dd-MM-yyyy hh:mm AP");

    bool is_assigned_update_query_run = obj_db_manager.execute_non_query(str_update_query, update_assigned_map);
    if (is_assigned_update_query_run)
    {
        qDebug() << "Unit" << unitId << "updated successfully.";
        emit inventory_changed();
    }

    qDebug() << "END: update_unit() ";
    return is_assigned_update_query_run;
}

bool inventory_manager::return_unit(int unitId)
{
    qDebug() << "START: return_unit() ";

    QString current_timestemp = QDateTime::currentDateTime().toString("dd-MM-yyyy hh:mm AP");

    QString str_return_query =
        "UPDATE asset_units SET "
        "status='Inactive', "
        "return_date=:return_date, "
        "last_updated=:last_updated "
        "WHERE id=:id";

    QVariantMap return_map;
    return_map[":id"]           = unitId;
    return_map[":return_date"]  = current_timestemp;
    return_map[":last_updated"] = current_timestemp;

    bool is_return_query_run = obj_db_manager.execute_non_query(str_return_query, return_map);
    if (is_return_query_run)
    {
        qDebug() << "Unit" << unitId << "returned successfully.";
        emit inventory_changed();
    }

    qDebug() << "END: return_unit() ";
    return is_return_query_run;
}

bool inventory_manager::delete_unit(int unitId)
{
    qDebug() << "START: delete_unit() ";

    QVariantMap delete_unit_map;
    delete_unit_map[":id"] = unitId;

    bool is_delete_query_run = obj_db_manager.execute_non_query("DELETE FROM asset_units WHERE id = :id", delete_unit_map);
    if (is_delete_query_run)
    {
        qDebug() << "Unit" << unitId << "deleted successfully.";
        emit inventory_changed();
    }

    qDebug() << "END: delete_unit() ";
    return is_delete_query_run;
}

QVariantList inventory_manager::search_units_by_person(const QString &name)
{
    QString assigned_unit_search_query_str =
        "SELECT u.*, a.asset_name, a.asset_category, a.asset_brand, a.asset_model "
        "FROM asset_units u "
        "JOIN assets a ON a.id = u.asset_ref_id "
        "WHERE u.assigned_to LIKE :name "
        "ORDER BY u.assigned_to ASC, u.assigned_date DESC";

    QVariantMap assigned_to_map;
    assigned_to_map[":name"] = "%" + name + "%";

    return obj_db_manager.execute_query(assigned_unit_search_query_str, assigned_to_map);
}

QVariantList inventory_manager::get_units_for_asset(int assetRefId)
{
    QVariantMap get_unit_map;
    get_unit_map[":ref_id"] = assetRefId;

    return obj_db_manager.execute_query(
        "SELECT * FROM asset_units WHERE asset_ref_id = :ref_id "
        "ORDER BY id DESC", get_unit_map);
}

QVariantList inventory_manager::get_all_units()
{
    return obj_db_manager.execute_query(
        "SELECT u.*, a.asset_name, a.asset_category "
        "FROM asset_units u "
        "JOIN assets a ON a.id = u.asset_ref_id "
        "ORDER BY u.id DESC", {});
}

//========== STATS=============

QVariantMap inventory_manager::get_inventory_statistics()
{
    qDebug() << "START: get_inventory_statistics() ";

    QString str_static_query =
        "SELECT "
        "  (SELECT COUNT(*) FROM assets) AS total_assets, "
        "  (SELECT COALESCE(SUM(total_quantity),0) FROM assets) AS total_units, "
        "  (SELECT COUNT(*) FROM asset_units WHERE status='Active')      AS active_units, "
        "  (SELECT COUNT(*) FROM asset_units WHERE status='Inactive')    AS inactive_units, "
        "  (SELECT COUNT(*) FROM asset_units WHERE status='Maintenance') AS maintenance_units";

    QVariantList result_map = obj_db_manager.execute_query(str_static_query, {});
    QVariantMap stats_map = result_map.isEmpty() ? QVariantMap() : result_map.first().toMap();

    qDebug() << "END: get_inventory_statistics() ";
    return stats_map;
}

//========== REPORT EXPORT =============

static QString csv_escape(const QVariant &value)
{
    QString s = value.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r'))
        s = "\"" + s.replace("\"", "\"\"") + "\"";
    return s;
}

bool inventory_manager::export_report(const QUrl &destination)
{
    qDebug() << "START: export_report() ";

    QString filePath = destination.isLocalFile() ? destination.toLocalFile() : destination.toString();
    if (!filePath.endsWith(".csv", Qt::CaseInsensitive))
        filePath += ".csv";

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
    {
        qDebug() << "END: export_report() — could not open file for writing:" << filePath;
        return false;
    }

    QTextStream out(&file);
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    out.setCodec("UTF-8");
#endif

    QStringList header =
        {
            "Asset ID", "Asset Name", "Category", "Brand", "Model", "Serial Number",
            "Total Quantity", "Assigned Quantity", "Pending Quantity", "Asset Created At",
            "Unit ID", "Assigned To", "Location", "Status", "Assigned Date", "Return Date", "Unit Notes"
        };
    out << header.join(",") << "\n";

    QVariantList assets = searched_assets("", "All");
    for (const QVariant &assetVar : assets)
    {
        QVariantMap asset = assetVar.toMap();
        QVariantList units = get_units_for_asset(asset["id"].toInt());

        QStringList assetCols =
            {
                csv_escape(asset["id"]),
                csv_escape(asset["asset_name"]),
                csv_escape(asset["asset_category"]),
                csv_escape(asset["asset_brand"]),
                csv_escape(asset["asset_model"]),
                csv_escape(asset["serial_number"]),
                csv_escape(asset["total_quantity"]),
                csv_escape(asset["assigned_quantity"]),
                csv_escape(asset["pending_quantity"]),
                csv_escape(asset["created_at"])
            };

        if (units.isEmpty())
        {
            out << assetCols.join(",") << ",,,,,,\n";
            continue;
        }

        for (const QVariant &unitVar : units)
        {
            QVariantMap unit = unitVar.toMap();
            QStringList unitCols =
                {
                    csv_escape(unit["asset_unit_id"]),
                    csv_escape(unit["assigned_to"]),
                    csv_escape(unit["asset_location"]),
                    csv_escape(unit["status"]),
                    csv_escape(unit["assigned_date"]),
                    csv_escape(unit["return_date"]),
                    csv_escape(unit["notes"])
                };
            out << assetCols.join(",") << "," << unitCols.join(",") << "\n";
        }
    }

    file.close();
    qDebug() << "END: export_report() — wrote" << filePath;
    return true;
}

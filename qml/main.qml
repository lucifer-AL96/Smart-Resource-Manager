import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform

ApplicationWindow
{
    id: window
    width: 1280
    height: 800
    visible: true
    title: "Smart Resource Manager"

    SystemPalette { id: sysPalette; colorGroup: SystemPalette.Active }

    readonly property bool isDarkMode:
    {
        var c = sysPalette.window
        var luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        return luminance < 0.5
    }

    readonly property color colorAccent:        isDarkMode ? "#8f7ffc" : "#6c4fdb"
    readonly property color colorAccentBright:   isDarkMode ? "#cabffb" : "#5a3fc0"
    readonly property color colorAccentDeep:     isDarkMode ? "#b4a9fc" : "#3b2f6b"
    readonly property color colorTeal:           isDarkMode ? "#4ecf9a" : "#0f9d71"
    readonly property color colorTealBg:         isDarkMode ? "#17332a" : "#e1f5ee"
    readonly property color colorOrange:         isDarkMode ? "#e3a25a" : "#c15a34"
    readonly property color colorOrangeBg:       isDarkMode ? "#3a2c18" : "#faece7"
    readonly property color colorBlue:           isDarkMode ? "#6fa8dc" : "#2f6fb0"
    readonly property color colorBlueBg:         isDarkMode ? "#1c2c3d" : "#e6f1fb"
    readonly property color colorGold:           isDarkMode ? "#e3c15a" : "#b58a1e"
    readonly property color colorGoldBg:         isDarkMode ? "#3a3218" : "#faeeda"
    readonly property color colorError:          isDarkMode ? "#f2777a" : "#c0392b"
    readonly property color colorErrorBg:        isDarkMode ? "#3a2226" : "#fbeaf0"

    readonly property color colorTextPrimary:    isDarkMode ? "#eae8f2" : "#2b2540"
    readonly property color colorTextDim:        isDarkMode ? "#9490ab" : "#8a82ad"
    readonly property color colorTextMuted:      isDarkMode ? "#82809c" : "#9b93c4"
    readonly property color colorTextFaint:      isDarkMode ? "#6b6780" : "#ada6ce"

    readonly property color colorBorder:         isDarkMode ? "#2c2c3a" : "#e4e0f5"
    readonly property color colorBorderStrong:   isDarkMode ? "#3a3a4d" : "#b4abe8"

    readonly property color colorSurface:        isDarkMode ? "#1b1b25" : "#ffffff"
    readonly property color colorSurfaceAlt:     isDarkMode ? "#21212c" : "#f4f1fc"
    readonly property color colorSurfaceActive:  isDarkMode ? "#2a2450" : "#ede9fb"

    readonly property color colorBgTop:          isDarkMode ? "#121218" : "#faf9f6"
    readonly property color colorBgMid:          isDarkMode ? "#15151d" : "#f5f2fb"
    readonly property color colorBgBottom:       isDarkMode ? "#121218" : "#f7f5f0"

    // === App state ===
    property int    selectedAssetId:        -1
    property string selectedCategoryFilter: "All"
    property string searchQuery:            ""
    property bool   isDetailPanelOpen:      true
    property bool   isAddFormOpen:          false
    property bool   isEditMode:             false
    property int    editingAssetId:         -1
    property var    assetList:              []
    property var    unitList:               []

    property bool   isAssignFormOpen: false
    property bool   isUnitEditMode:   false
    property int    editingUnitId:   -1

    property string detailPanelTab: "overview"

    // === People search state ===
    property string searchMode:    "assets"
    property var    personResults: []

    readonly property var customCategoryList:
    {
        var list     = []
        var standard = ["Laptop", "Desktop", "Storage", "Printer", "Network"]
        for (var i = 0; i < assetList.length; i++)
        {
            var cat = assetList[i].asset_category
            if (cat && standard.indexOf(cat) === -1 && list.indexOf(cat) === -1)
                list.push(cat)
        }
        return list.sort()
    }

    background: Rectangle
    {
        gradient: Gradient
        {
            GradientStop { position: 0.0; color: colorBgTop }
            GradientStop { position: 0.5; color: colorBgMid }
            GradientStop { position: 1.0; color: colorBgBottom }
        }
    }

    component CopyableText: TextEdit
    {
        readOnly: true
        selectByMouse: true
        persistentSelection: true
        wrapMode: TextEdit.NoWrap
        verticalAlignment: TextEdit.AlignVCenter
        color: colorTextPrimary
        font.pixelSize: 12
        selectionColor: colorAccent
        selectedTextColor: colorSurface
        cursorVisible: false
        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
    }

    Component.onCompleted: refreshEverything()

    property bool lastExportOk: true

    Platform.FileDialog
    {
        id: exportDialog
        title: "Export inventory report"
        fileMode: Platform.FileDialog.SaveFile
        nameFilters: ["CSV file (*.csv)"]
        defaultSuffix: "csv"
        currentFile: "file:///Smart_Resources_Manager.csv"

        onAccepted:
        {
            window.lastExportOk = inventory_backend.export_report(exportDialog.file)
            exportResultDialog.open()
        }
    }

    Platform.MessageDialog
    {
        id: exportResultDialog
        title: window.lastExportOk ? "Export complete" : "Export failed"
        text: window.lastExportOk
              ? "Asset & assigned-unit report exported successfully to:\n" + exportDialog.file.toString().replace("file://", "")
              : "Could not write the CSV file to the selected location. Please try a different destination."
    }

    function refreshAssetData()
    {
        window.assetList = inventory_backend.get_all_assets()
    }

    function categoryIconSource(cat)
    {
        if (cat === "Laptop")  return "qrc:/icons/laptop.png"
        if (cat === "Desktop") return "qrc:/icons/desktop.png"
        if (cat === "Storage") return "qrc:/icons/storage.png"
        if (cat === "Printer") return "qrc:/icons/printer.png"
        if (cat === "Network") return "qrc:/icons/network.png"
        return "qrc:/icons/package.png"
    }

    function refreshUnitData()
    {
        if (selectedAssetId !== -1)
            window.unitList = inventory_backend.get_units_for_asset(selectedAssetId)
        else
            window.unitList = []
    }

    function syncSelectionAfterRefresh()
    {
        if (selectedAssetId === -1) { setFirstVisibleAsset(); return }

        var found = -1
        for (var i = 0; i < window.assetList.length; i++)
        {
            if (window.assetList[i].id === selectedAssetId) { found = i; break }
        }

        if (found === -1)
            setFirstVisibleAsset()
        else
            tableViewList.currentIndex = found
    }

    function refreshEverything()
    {
        refreshAssetData()
        syncSelectionAfterRefresh()
        refreshUnitData()
    }

    function resetToDefault()
    {
        txtSearch.text         = ""
        searchQuery            = ""
        selectedCategoryFilter = "All"
        searchMode             = "assets"
        personResults          = []
        isDetailPanelOpen      = true
        detailPanelTab         = "overview"
        refreshAssetData()
        setFirstVisibleAsset()
        refreshUnitData()
    }

    function setFirstVisibleAsset()
    {
        for (var i = 0; i < window.assetList.length; i++)
        {
            var d = window.assetList[i]

            var catOk = selectedCategoryFilter === "All" ||
                    d.asset_category === selectedCategoryFilter

            var srchOk = searchQuery === "" ||
                    (d.asset_name    || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                    (d.serial_number || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                    (d.asset_brand   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                    (d.asset_model   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1

            if (catOk && srchOk)
            {
                selectedAssetId            = d.id
                tableViewList.currentIndex = i
                return
            }
        }
        selectedAssetId            = -1
        tableViewList.currentIndex = -1
    }

    onSelectedCategoryFilterChanged:
    {
        setFirstVisibleAsset()
        isDetailPanelOpen = true
    }

    onSearchQueryChanged: setFirstVisibleAsset()

    onSelectedAssetIdChanged:
    {
        detailPanelTab   = "overview"
        isAssignFormOpen = false
        isUnitEditMode   = false
        editingUnitId    = -1
        refreshUnitData()
    }

    RowLayout
    {
        anchors.fill: parent
        spacing: 0

        // ===
        // LEFT SIDEBAR
        // ===
        Rectangle
        {
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            color: colorSurface
            border.color: colorBorder
            border.width: 1

            ColumnLayout
            {
                anchors.fill: parent
                spacing: 0

                Rectangle
                {
                    Layout.fillWidth: true
                    height: 70
                    color: colorSurface

                    RowLayout
                    {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10

                        Rectangle
                        {
                            width: 40; height: 40; radius: 10
                            color: colorAccent
                            Image
                            {
                                anchors.centerIn: parent
                                width: 78; height: 78
                                source: "qrc:/icons/logo.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true; mipmap: true
                                asynchronous: true
                            }
                        }

                        Column
                        {
                            spacing: 2
                            Text { text: "Smart Resource Manager"; color: colorTextPrimary; font.bold: true; font.pixelSize: 14 }
                            Rectangle
                            {
                                width: verText.implicitWidth + 12; height: 16; radius: 8
                                color: colorSurfaceActive; border.color: colorBorderStrong; border.width: 1
                                Text { id: verText; anchors.centerIn: parent; text: "v1.0 Pro"; color: colorAccent; font.pixelSize: 9; font.bold: true }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: colorBorder }

                ColumnLayout
                {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 10
                    spacing: 2

                    Text
                    {
                        text: "OVERVIEW"
                        color: colorTextMuted; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2
                        topPadding: 8; bottomPadding: 4; leftPadding: 6
                    }

                    Rectangle
                    {
                        Layout.fillWidth: true
                        height: 42; radius: 8
                        readonly property color activeBg: colorSurfaceActive
                        readonly property color activeBorder: colorAccent
                        color: Qt.rgba(activeBg.r, activeBg.g, activeBg.b, selectedCategoryFilter === "All" ? 1 : 0)
                        border.color: Qt.rgba(activeBorder.r, activeBorder.g, activeBorder.b, selectedCategoryFilter === "All" ? 1 : 0)
                        border.width: 1

                        Rectangle
                        {
                            width: 3; height: 22
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            radius: 2; color: colorAccent
                            visible: selectedCategoryFilter === "All"
                        }

                        RowLayout
                        {
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 10
                            spacing: 10

                            Text
                            {
                                text: "All Registered Units"
                                color: selectedCategoryFilter === "All" ? colorAccentDeep : colorTextDim
                                font.pixelSize: 12; font.bold: selectedCategoryFilter === "All"
                                Layout.fillWidth: true
                            }

                            Rectangle
                            {
                                width: allBadge.implicitWidth + 12; height: 20; radius: 10; color: colorSurfaceActive
                                Text
                                {
                                    id: allBadge
                                    anchors.centerIn: parent
                                    text: {
                                        var n = 0
                                        for (var i = 0; i < window.assetList.length; i++)
                                            n += parseInt(window.assetList[i].total_quantity) || 0
                                        return n
                                    }
                                    color: colorAccent; font.pixelSize: 10; font.bold: true
                                }
                            }
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchMode = "assets"; selectedCategoryFilter = "All" } }
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    Text
                    {
                        text: "CATEGORIES"
                        color: colorTextMuted; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2
                        topPadding: 10; bottomPadding: 4; leftPadding: 6
                    }

                    component SidebarCatItem: Rectangle
                    {
                        property string catName: ""
                        property color  catColor: colorAccent
                        property color  catBgActive: colorSurfaceActive

                        Layout.fillWidth: true
                        height: 38; radius: 8
                        color: Qt.rgba(catBgActive.r, catBgActive.g, catBgActive.b, selectedCategoryFilter === catName ? 1 : 0)
                        border.color: Qt.rgba(catColor.r, catColor.g, catColor.b, selectedCategoryFilter === catName ? 1 : 0)
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        Rectangle
                        {
                            width: 3; height: 18
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            radius: 2; color: catColor
                            visible: selectedCategoryFilter === catName
                        }

                        RowLayout
                        {
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 10
                            spacing: 10

                            Rectangle { width: 7; height: 7; radius: 4; color: catColor }

                            Text
                            {
                                text: catName
                                color: selectedCategoryFilter === catName ? catColor : colorTextDim
                                font.pixelSize: 12; font.bold: selectedCategoryFilter === catName
                                Layout.fillWidth: true
                            }

                            Rectangle
                            {
                                width: catBadge.implicitWidth + 12; height: 20; radius: 10
                                color: Qt.rgba(catColor.r, catColor.g, catColor.b, 0.12)
                                Text
                                {
                                    id: catBadge
                                    anchors.centerIn: parent
                                    text: {
                                        var n = 0
                                        for (var i = 0; i < window.assetList.length; i++)
                                            if (window.assetList[i].asset_category === catName)
                                                n += parseInt(window.assetList[i].total_quantity) || 0
                                        return n
                                    }
                                    color: catColor; font.pixelSize: 10; font.bold: true
                                }
                            }
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchMode = "assets"; selectedCategoryFilter = catName } }
                    }

                    SidebarCatItem { catName: "Laptop";  catColor: colorAccent; catBgActive: colorSurfaceActive }
                    SidebarCatItem { catName: "Desktop"; catColor: colorTeal; catBgActive: colorTealBg }
                    SidebarCatItem { catName: "Storage"; catColor: colorBlue; catBgActive: colorBlueBg }
                    SidebarCatItem { catName: "Printer"; catColor: colorOrange; catBgActive: colorOrangeBg }
                    SidebarCatItem { catName: "Network"; catColor: colorGold; catBgActive: colorGoldBg }

                    Text
                    {
                        text: "CUSTOM CATEGORIES"
                        color: colorTextMuted; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2
                        topPadding: 10; bottomPadding: 4; leftPadding: 6
                        visible: window.customCategoryList.length > 0
                    }

                    Repeater
                    {
                        model: window.customCategoryList
                        Rectangle
                        {
                            property string catName: modelData
                            readonly property color customBg: colorGoldBg
                            readonly property color customBorder: colorGold
                            Layout.fillWidth: true
                            height: 38; radius: 8
                            color: Qt.rgba(customBg.r, customBg.g, customBg.b, selectedCategoryFilter === catName ? 1 : 0)
                            border.color: Qt.rgba(customBorder.r, customBorder.g, customBorder.b, selectedCategoryFilter === catName ? 1 : 0)
                            border.width: 1
                            Behavior on color        { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            Rectangle
                            {
                                width: 3; height: 18
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                radius: 2; color: colorGold
                                visible: selectedCategoryFilter === catName
                            }

                            RowLayout
                            {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 10
                                spacing: 10

                                Rectangle { width: 7; height: 7; radius: 4; color: colorGold }
                                Text
                                {
                                    text: catName
                                    color: selectedCategoryFilter === catName ? colorGold : colorTextDim
                                    font.pixelSize: 12; font.bold: selectedCategoryFilter === catName
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Rectangle
                                {
                                    width: customBadge.implicitWidth + 12; height: 20; radius: 10; color: colorGoldBg
                                    Text
                                    {
                                        id: customBadge
                                        anchors.centerIn: parent
                                        text: {
                                            var n = 0
                                            for (var i = 0; i < window.assetList.length; i++)
                                                if (window.assetList[i].asset_category === catName)
                                                    n += parseInt(window.assetList[i].total_quantity) || 0
                                            return n
                                        }
                                        color: colorGold; font.pixelSize: 10; font.bold: true
                                    }
                                }
                            }

                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchMode = "assets"; selectedCategoryFilter = catName } }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle
                    {
                        Layout.fillWidth: true
                        height: 38; radius: 8
                        color: exportMouse.containsMouse ? colorTealBg : colorSurface
                        border.color: exportMouse.containsMouse ? colorTeal : colorBorder
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        RowLayout
                        {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "⭳"; color: exportMouse.containsMouse ? colorTeal : colorTextDim; font.pixelSize: 15; Behavior on color { ColorAnimation { duration: 100 } } }
                            Text { text: "Export Report"; color: exportMouse.containsMouse ? colorTeal : colorTextDim; font.pixelSize: 11; font.bold: true; Behavior on color { ColorAnimation { duration: 100 } } }
                        }

                        MouseArea { id: exportMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: exportDialog.open() }
                    }

                    Item { height: 8 }

                    Rectangle
                    {
                        Layout.fillWidth: true
                        height: 38; radius: 8
                        color: refreshMouse.containsMouse ? colorSurfaceActive : colorSurface
                        border.color: refreshMouse.containsMouse ? colorAccent : colorBorder
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        RowLayout
                        {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "↺"; color: refreshMouse.containsMouse ? colorAccent : colorTextDim; font.pixelSize: 16; Behavior on color { ColorAnimation { duration: 100 } } }
                            Text { text: "Reset & Refresh"; color: refreshMouse.containsMouse ? colorAccent : colorTextDim; font.pixelSize: 11; font.bold: true; Behavior on color { ColorAnimation { duration: 100 } } }
                        }

                        MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.resetToDefault() }
                    }

                    Item { height: 6 }
                }
            }
        }

        // ===
        // MIDDLE PANEL
        // ===
        Rectangle
        {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: "transparent"

            ColumnLayout
            {
                anchors.fill: parent
                anchors.margins: 25
                spacing: 15

                RowLayout
                {
                    Layout.fillWidth: true
                    Column
                    {
                        Text { text: "Resources Dashboard"; color: colorTextPrimary; font.bold: true; font.pixelSize: 22 }
                        Text { text: "Master catalog with per-unit assignment tracking."; color: colorTextDim; font.pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    Button
                    {
                        text: isAddFormOpen ? "Cancel" : "Add Asset +"
                        background: Rectangle { implicitWidth: 130; implicitHeight: 38; radius: 8; color: isAddFormOpen ? colorError : colorAccent }
                        contentItem: Text { text: parent.text; color: "white"; font.bold: true; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked:
                        {
                            isEditMode     = false
                            editingAssetId = -1
                            isAddFormOpen  = !isAddFormOpen
                            if (isAddFormOpen)
                            {
                                asset_name_text.text = ""; asset_brand_text.text = ""; asset_model_text.text = ""
                                asset_number_text.text = ""; asset_serial_number_text.text = ""
                                asset_specs_text.text = ""; asset_Note_text.text = ""
                                asset_custom_category_text.text = ""
                                asset_category_combobox.currentIndex = 0
                            }
                        }
                    }
                }

                // === Add / Edit Asset form ===
                Rectangle
                {
                    Layout.fillWidth: true
                    visible: isAddFormOpen
                    radius: 14
                    color: colorSurface
                    border.color: isEditMode ? colorOrange : colorAccent
                    border.width: 1.5
                    Layout.preferredHeight: 280

                    ColumnLayout
                    {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 10

                        RowLayout
                        {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle
                            {
                                width: 34; height: 34; radius: 9
                                color: isEditMode ? colorOrangeBg : colorSurfaceActive
                                border.color: isEditMode ? colorOrange : colorAccent; border.width: 1
                                Image { anchors.centerIn: parent; width: 18; height: 18; source: isEditMode ? "qrc:/icons/edit.png" : "qrc:/icons/package.png";
                                    fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true }
                            }

                            Column
                            {
                                spacing: 1
                                Text { text: isEditMode ? "Update asset" : "Register new asset"; color: isEditMode ? colorOrange : colorTextPrimary; font.bold: true; font.pixelSize: 14 }
                                Text { text: "Fields marked * are required"; color: colorBorderStrong; font.pixelSize: 10 }
                            }

                            Item { Layout.fillWidth: true }
                        }


                        Rectangle { Layout.fillWidth: true; height: 1; color: colorBorder }

                        RowLayout
                        {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Asset name *"; color: asset_name_text.empty_box ? colorError : colorAccent; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_name_text
                                    property bool empty_box: false
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "Dell Latitude 5420"; color: colorTextPrimary; font.pixelSize: 11
                                    background: Rectangle { color: colorSurfaceAlt; border.color: asset_name_text.empty_box ? colorError : colorBorder; radius: 7 }
                                }
                            }

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Brand"; color: colorTextDim; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_brand_text
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "Dell"; color: colorTextPrimary; font.pixelSize: 11
                                    background: Rectangle { color: colorSurfaceAlt; border.color: colorBorder; radius: 7 }
                                }
                            }

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Model"; color: colorTextDim; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_model_text
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "Latitude 5420"; color: colorTextPrimary; font.pixelSize: 11
                                    background: Rectangle { color: colorSurfaceAlt; border.color: colorBorder; radius: 7 }
                                }
                            }

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Total quantity *"; color: asset_number_text.empty_box ? colorError : colorAccent; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_number_text
                                    property bool empty_box: false
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "25"; color: colorTextPrimary; font.pixelSize: 11
                                    validator: IntValidator { bottom: 1 }
                                    background: Rectangle { color: colorSurfaceAlt; border.color: asset_number_text.empty_box ? colorError : colorBorder; radius: 7 }
                                }
                            }
                        }

                        RowLayout
                        {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Serial number"; color: colorTextDim; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_serial_number_text
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "SN-882-XYZ"; color: colorTextPrimary; font.pixelSize: 11
                                    background: Rectangle { color: colorSurfaceAlt; border.color: colorBorder; radius: 7 }
                                }
                            }

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Specification"; color: colorTextDim; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_specs_text
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "16GB RAM, 512GB SSD"; color: colorTextPrimary; font.pixelSize: 11
                                    background: Rectangle { color: colorSurfaceAlt; border.color: colorBorder; radius: 7 }
                                }
                            }

                            //=== Category===
                            ColumnLayout
                            {
                                Layout.preferredWidth: 160; spacing: 4
                                Text { text: "Category *"; color: asset_category_combobox.empty_box ? colorError : colorAccent; font.pixelSize: 10; font.bold: true }

                                ComboBox
                                {
                                    id: asset_category_combobox
                                    property bool empty_box: false
                                    Layout.fillWidth: true
                                    model: ["Select category", "Laptop", "Desktop", "Storage", "Printer", "Network", "Custom Category"]

                                    function categoryColor(cat)
                                    {
                                        if (cat === "Laptop")  return colorAccent
                                        if (cat === "Desktop") return colorTeal
                                        if (cat === "Storage") return colorBlue
                                        if (cat === "Printer") return colorOrange
                                        if (cat === "Network") return colorGold
                                        return colorOrange
                                    }
                                    readonly property bool isPlaceholder: currentText === "Select category"

                                    background: Rectangle
                                    {
                                        color:        asset_category_combobox.pressed ? colorSurfaceActive : asset_category_combobox.hovered ? colorSurfaceAlt : colorSurfaceAlt
                                        border.color: asset_category_combobox.empty_box ? colorError : asset_category_combobox.pressed ? colorAccent : asset_category_combobox.hovered ? colorBorderStrong : colorBorder
                                        border.width: asset_category_combobox.pressed ? 1.5 : 1
                                        radius: 7; implicitHeight: 32
                                        Behavior on color        { ColorAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                    }

                                    contentItem: RowLayout
                                    {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 0
                                        Rectangle { width: 7; height: 7; radius: 4; Layout.alignment: Qt.AlignVCenter; visible: !asset_category_combobox.isPlaceholder; color: asset_category_combobox.categoryColor(asset_category_combobox.currentText) }
                                        Item { width: 6; visible: !asset_category_combobox.isPlaceholder }
                                        Text
                                        {
                                            text: asset_category_combobox.displayText
                                            color: asset_category_combobox.isPlaceholder ? colorTextFaint : asset_category_combobox.categoryColor(asset_category_combobox.currentText)
                                            verticalAlignment: Text.AlignVCenter; font.pixelSize: 11; font.bold: !asset_category_combobox.isPlaceholder; Layout.fillWidth: true
                                        }
                                    }

                                    popup: Popup
                                    {
                                        y: asset_category_combobox.height + 4; width: asset_category_combobox.width; padding: 4
                                        background: Rectangle { color: colorSurface; border.color: colorBorder; border.width: 1; radius: 10; Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border.color: isDarkMode ? "#40ffffff" : "#12000000"; border.width: 1; radius: 11; z: -1 } }
                                        contentItem: ListView { implicitHeight: contentHeight; model: asset_category_combobox.delegateModel; clip: true }
                                    }

                                    delegate: ItemDelegate
                                    {
                                        width: asset_category_combobox.width - 8
                                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                        highlighted: asset_category_combobox.highlightedIndex === index
                                        readonly property bool isPlaceholderItem: modelData === "Select category"

                                        background: Rectangle { color: parent.highlighted ? colorSurfaceActive : parent.hovered ? colorSurfaceAlt : "transparent"; radius: 7; Behavior on color { ColorAnimation { duration: 80 } } }
                                        contentItem: RowLayout
                                        {
                                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                            Rectangle { width: 7; height: 7; radius: 4; Layout.alignment: Qt.AlignVCenter; visible: !isPlaceholderItem; color: asset_category_combobox.categoryColor(modelData) }
                                            Text { text: modelData; color: isPlaceholderItem ? colorTextFaint : asset_category_combobox.categoryColor(modelData); font.pixelSize: 11; font.bold: !isPlaceholderItem; Layout.fillWidth: true; verticalAlignment: Text.AlignVCenter }
                                            Text { text: "✓"; color: colorAccent; font.pixelSize: 11; visible: !isPlaceholderItem && asset_category_combobox.currentText === modelData; Layout.alignment: Qt.AlignVCenter }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout
                        {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Note"; color: colorTextDim; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_Note_text
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "Any additional notes"; color: colorTextPrimary; font.pixelSize: 11
                                    background: Rectangle { color: colorSurfaceAlt; border.color: colorBorder; radius: 7 }
                                }
                            }

                            ColumnLayout
                            {
                                Layout.fillWidth: true; spacing: 4
                                visible: asset_category_combobox.currentText === "Custom Category"
                                Text { text: "Custom category name *"; color: asset_custom_category_text.empty_box ? colorError : colorAccent; font.pixelSize: 10; font.bold: true }
                                TextField
                                {
                                    id: asset_custom_category_text
                                    property bool empty_box: false
                                    Layout.fillWidth: true; height: 32
                                    placeholderText: "Packing Resource"; color: colorTextPrimary; font.pixelSize: 11
                                    background: Rectangle { color: colorSurfaceAlt; border.color: asset_custom_category_text.empty_box ? colorError : colorBorder; radius: 7 }
                                }
                            }
                        }

                        RowLayout
                        {
                            Layout.fillWidth: true; spacing: 10
                            Item { Layout.fillWidth: true }

                            Button
                            {

                                implicitWidth: 170; implicitHeight: 36
                                text: isEditMode ? "Save changes" : "Register asset"
                                background: Rectangle { color: isEditMode ? colorOrange : colorAccent; radius: 9 }
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked:
                                {
                                    asset_name_text.empty_box         = asset_name_text.text.trim() === ""
                                    asset_number_text.empty_box       = asset_number_text.text.trim() === "" || parseInt(asset_number_text.text) <= 0
                                    asset_category_combobox.empty_box = asset_category_combobox.currentIndex === 0

                                    var isCustom = asset_category_combobox.currentText === "Custom Category"
                                    if (isCustom)
                                        asset_custom_category_text.empty_box = asset_custom_category_text.text.trim() === ""

                                    if (asset_name_text.empty_box || asset_number_text.empty_box ||
                                            asset_category_combobox.empty_box ||
                                            (isCustom && asset_custom_category_text.empty_box))
                                        return

                                    var finalCategory = isCustom
                                            ? asset_custom_category_text.text.trim()
                                            : asset_category_combobox.currentText

                                    var itemData =
                                            {
                                        "asset_name":     asset_name_text.text.trim(),
                                        "asset_category": finalCategory,
                                        "total_quantity": parseInt(asset_number_text.text),
                                        "asset_brand":    asset_brand_text.text.trim()         !== "" ? asset_brand_text.text.trim()         : "Unknown",
                                        "asset_model":    asset_model_text.text.trim()         !== "" ? asset_model_text.text.trim()         : "Unknown",
                                        "serial_number":  asset_serial_number_text.text.trim() !== "" ? asset_serial_number_text.text.trim() : "Unknown",
                                        "asset_specs":    asset_specs_text.text.trim(),
                                        "notes":          asset_Note_text.text.trim()
                                    }

                                    var success = false
                                    if (isEditMode && editingAssetId > 0)
                                        success = inventory_backend.update_asset(editingAssetId, itemData)
                                    else
                                        success = inventory_backend.add_asset(itemData)

                                    if (success)
                                    {
                                        isAddFormOpen  = false
                                        isEditMode     = false
                                        editingAssetId = -1

                                        asset_name_text.text            = ""
                                        asset_brand_text.text           = ""
                                        asset_model_text.text           = ""
                                        asset_number_text.text          = ""
                                        asset_serial_number_text.text   = ""
                                        asset_specs_text.text           = ""
                                        asset_Note_text.text            = ""
                                        asset_custom_category_text.text = ""
                                        asset_category_combobox.currentIndex = 0
                                        refreshEverything()
                                    }
                                }
                            }
                        }
                    }
                }

                // === Search bar with mode toggle ===
                RowLayout
                {
                    Layout.fillWidth: true
                    spacing: 10

                    Row
                    {
                        spacing: 2
                        Rectangle
                        {
                            width: 70; height: 38; radius: 8
                            color: searchMode === "assets" ? colorAccent : colorSurface
                            border.color: searchMode === "assets" ? colorAccent : colorBorder
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "Assets"; color: searchMode === "assets" ? "white" : colorTextDim; font.pixelSize: 11; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchMode = "assets"; txtSearch.text = "" } }
                        }
                        Rectangle
                        {
                            width: 70; height: 38; radius: 8
                            color: searchMode === "people" ? colorAccent : colorSurface
                            border.color: searchMode === "people" ? colorAccent : colorBorder
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "People"; color: searchMode === "people" ? "white" : colorTextDim; font.pixelSize: 11; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchMode = "people"; txtSearch.text = "" } }
                        }
                    }

                    Rectangle
                    {
                        Layout.fillWidth: true
                        height: 38; radius: 8
                        color: colorSurface
                        border.color: txtSearch.activeFocus ? colorAccent : colorBorder
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout
                        {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 6
                            spacing: 6

                            TextField
                            {
                                id: txtSearch
                                Layout.fillWidth: true
                                placeholderText: searchMode === "assets"
                                                 ? "Search by name, brand, model, serial number..."
                                                 : "Search by person name — e.g. Ajay"
                                placeholderTextColor: colorTextFaint
                                color: colorTextPrimary; font.pixelSize: 11
                                background: Item {}
                                onTextChanged:
                                {
                                    if (searchMode === "assets")
                                    {
                                        searchQuery = text
                                    }
                                    else
                                    {
                                        personResults = text.trim() === "" ? [] : inventory_backend.search_units_by_person(text.trim())
                                    }
                                }
                            }

                            Rectangle
                            {
                                width: 22; height: 22; radius: 11
                                visible: txtSearch.text.length > 0
                                color: clearMouse.containsMouse ? colorErrorBg : "transparent"
                                border.color: clearMouse.containsMouse ? colorError : colorBorderStrong
                                border.width: 1
                                Behavior on color        { ColorAnimation { duration: 80 } }
                                Behavior on border.color { ColorAnimation { duration: 80 } }

                                Text { anchors.centerIn: parent; text: "✕"; color: clearMouse.containsMouse ? colorError : colorTextDim; font.pixelSize: 10; font.bold: true; Behavior on color { ColorAnimation { duration: 80 } } }
                                MouseArea
                                {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                    {
                                        txtSearch.text = ""
                                        txtSearch.forceActiveFocus()
                                        if (searchMode === "people") personResults = []
                                    }
                                }
                            }
                        }
                    }
                }

                // === MASTER TABLE (Assets mode) ===
                Rectangle
                {
                    id: tableRoot
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    visible: searchMode === "assets"
                    radius: 12; color: colorSurface; border.color: colorBorder
                    readonly property int tableContentWidth: 910
                    property string sortColumn:    ""
                    property bool   sortAscending: true

                    function sortBy(columnKey)
                    {
                        if (columnKey === "") return
                        if (tableRoot.sortColumn === columnKey)
                            tableRoot.sortAscending = !tableRoot.sortAscending
                        else { tableRoot.sortColumn = columnKey; tableRoot.sortAscending = true }

                        window.assetList = inventory_backend.get_sorted_assets(
                                    columnKey, tableRoot.sortAscending,
                                    selectedCategoryFilter === "All" ? "" : selectedCategoryFilter,
                                    searchQuery)
                        syncSelectionAfterRefresh()
                    }

                    ColumnLayout
                    {
                        anchors.fill: parent
                        spacing: 0

                        Item
                        {
                            Layout.fillWidth: true; height: 38; clip: true
                            Rectangle { anchors.fill: parent; color: colorSurfaceAlt; radius: 12 }

                            Row
                            {
                                x: -flickable.contentX; height: parent.height; spacing: 0
                                Item { width: 15; height: parent.height }
                                Item { width: 50; height: parent.height; Text { anchors.centerIn: parent; text: "#"; color: colorTextDim; font.bold: true; font.pixelSize: 12 } }
                                Item { width: 10; height: parent.height }

                                component HeaderCell: Item
                                {
                                    property string colLabel: ""
                                    property string colKey:   ""
                                    property int    colWidth: 120

                                    width: colWidth; height: 38
                                    Rectangle { anchors.fill: parent; color: hdrMouse.containsMouse ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.08) : "transparent"; Behavior on color { ColorAnimation { duration: 120 } } }
                                    Row { anchors.centerIn: parent; spacing: 4
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: colLabel; color: tableRoot.sortColumn === colKey ? colorTextPrimary : colorTextDim; font.bold: true; font.pixelSize: 12 }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: tableRoot.sortAscending ? "↑" : "↓"; color: colorAccent; font.pixelSize: 11; visible: tableRoot.sortColumn === colKey }
                                    }
                                    MouseArea { id: hdrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tableRoot.sortBy(colKey) }
                                }

                                HeaderCell { colLabel: "Asset Name";  colKey: "asset_name";        colWidth: 150 }
                                Item { width: 10; height: parent.height }
                                HeaderCell { colLabel: "Category";    colKey: "asset_category";    colWidth: 110 }
                                Item { width: 10; height: parent.height }
                                HeaderCell { colLabel: "Total";       colKey: "total_quantity";    colWidth: 90  }
                                Item { width: 10; height: parent.height }
                                HeaderCell { colLabel: "Pending";     colKey: "pending_quantity";  colWidth: 90  }
                                Item { width: 10; height: parent.height }
                                HeaderCell { colLabel: "Serial No.";  colKey: "serial_number";     colWidth: 120 }
                                Item { width: 10; height: parent.height }
                                HeaderCell { colLabel: "Brand";       colKey: "asset_brand";       colWidth: 100 }
                                Item { width: 10; height: parent.height }
                                HeaderCell { colLabel: "Model";       colKey: "asset_model";       colWidth: 100 }
                                Item { width: 15; height: parent.height }
                            }
                        }

                        Flickable
                        {
                            id: flickable
                            Layout.fillWidth: true; Layout.fillHeight: true
                            contentWidth: tableRoot.tableContentWidth
                            contentHeight: tableViewList.contentHeight
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded; interactive: true }
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; interactive: true }

                            ListView
                            {
                                id: tableViewList
                                width: Math.max(flickable.width, tableRoot.tableContentWidth)
                                height: contentHeight
                                interactive: false; clip: true
                                model: window.assetList
                                focus: true

                                Component.onCompleted: forceActiveFocus()

                                Keys.onPressed: (event) =>
                                                {
                                                    if (event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) return

                                                    var visibleIdx = []
                                                    for (var i = 0; i < window.assetList.length; i++)
                                                    {
                                                        var d = window.assetList[i]
                                                        var catOk = selectedCategoryFilter === "All" || d.asset_category === selectedCategoryFilter
                                                        var srchOk = searchQuery === "" ||
                                                        (d.asset_name    || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                                        (d.serial_number || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                                        (d.asset_brand   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                                        (d.asset_model   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1
                                                        if (catOk && srchOk) visibleIdx.push(i)
                                                    }

                                                    var pos = visibleIdx.indexOf(tableViewList.currentIndex)

                                                    if (event.key === Qt.Key_Up && pos > 0)
                                                    {
                                                        tableViewList.currentIndex = visibleIdx[pos - 1]
                                                        selectedAssetId = window.assetList[tableViewList.currentIndex].id
                                                        tableViewList.positionViewAtIndex(tableViewList.currentIndex, ListView.Contain)
                                                        event.accepted = true
                                                    }
                                                    else if (event.key === Qt.Key_Down && pos !== -1 && pos < visibleIdx.length - 1)
                                                    {
                                                        tableViewList.currentIndex = visibleIdx[pos + 1]
                                                        selectedAssetId = window.assetList[tableViewList.currentIndex].id
                                                        tableViewList.positionViewAtIndex(tableViewList.currentIndex, ListView.Contain)
                                                        event.accepted = true
                                                    }
                                                }

                                delegate: Item
                                {
                                    id: delegateRoot

                                    readonly property bool matchesCategory: selectedCategoryFilter === "All" || modelData.asset_category === selectedCategoryFilter
                                    readonly property bool matchesSearch:
                                        searchQuery === "" ||
                                        (modelData.asset_name    || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                        (modelData.serial_number || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                        (modelData.asset_brand   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                        (modelData.asset_model   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1

                                    readonly property bool isRowVisible: matchesCategory && matchesSearch

                                    readonly property int rowNumber:
                                    {
                                        var n = 0
                                        for (var i = 0; i < index; i++)
                                        {
                                            var d = window.assetList[i]
                                            var cOk = selectedCategoryFilter === "All" || d.asset_category === selectedCategoryFilter
                                            var qOk = searchQuery === "" ||
                                                    (d.asset_name    || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                                    (d.serial_number || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                                    (d.asset_brand   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1 ||
                                                    (d.asset_model   || "").toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1
                                            if (cOk && qOk) n++
                                        }
                                        return n + 1
                                    }

                                    width:   tableRoot.tableContentWidth
                                    height:  isRowVisible ? 50 : 0
                                    visible: isRowVisible; clip: true

                                    Rectangle
                                    {
                                        anchors.fill: parent
                                        color:        modelData.id === selectedAssetId ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.10) : "transparent"
                                        border.color: modelData.id === selectedAssetId ? colorAccent  : "transparent"
                                        border.width: modelData.id === selectedAssetId ? 1 : 0

                                        Row
                                        {
                                            anchors.fill: parent; spacing: 0
                                            Item { width: 15; height: parent.height }
                                            Item { width: 50;  height: parent.height; Text { anchors.centerIn: parent; text: delegateRoot.rowNumber; color: colorTextMuted; font.pixelSize: 11; font.bold: true } }
                                            Item { width: 10;  height: parent.height }
                                            Item { width: 150; height: parent.height; Text { anchors.centerIn: parent; text: modelData.asset_name; color: colorTextPrimary; font.bold: true; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 4; horizontalAlignment: Text.AlignHCenter } }
                                            Item { width: 10;  height: parent.height }
                                            Item { width: 110; height: parent.height; Text { anchors.centerIn: parent; text: modelData.asset_category; color: colorTextDim; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 4; horizontalAlignment: Text.AlignHCenter } }
                                            Item { width: 10;  height: parent.height }
                                            Item { width: 90;  height: parent.height; Text { anchors.centerIn: parent; text: modelData.total_quantity; color: colorTextPrimary; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter } }
                                            Item { width: 10;  height: parent.height }
                                            Item
                                            {
                                                width: 90;  height: parent.height
                                                Text
                                                {
                                                    anchors.centerIn: parent
                                                    text: modelData.pending_quantity
                                                    color: parseInt(modelData.pending_quantity) > 0 ? colorTeal : colorError
                                                    font.bold: true; font.pixelSize: 11
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                            Item { width: 10;  height: parent.height }
                                            Item { width: 120; height: parent.height; Text { anchors.centerIn: parent; text: modelData.serial_number; color: colorTextPrimary; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 4; horizontalAlignment: Text.AlignHCenter } }
                                            Item { width: 10;  height: parent.height }
                                            Item { width: 100; height: parent.height; Text { anchors.centerIn: parent; text: modelData.asset_brand; color: colorTextDim; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 4; horizontalAlignment: Text.AlignHCenter } }
                                            Item { width: 10;  height: parent.height }
                                            Item { width: 100; height: parent.height; Text { anchors.centerIn: parent; text: modelData.asset_model; color: colorTextDim; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 4; horizontalAlignment: Text.AlignHCenter } }
                                            Item { width: 15;  height: parent.height }
                                        }

                                        MouseArea
                                        {
                                            anchors.fill: parent
                                            onClicked:
                                            {
                                                selectedAssetId            = modelData.id
                                                tableViewList.currentIndex = index
                                                tableViewList.forceActiveFocus()
                                                isDetailPanelOpen          = true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle
                        {
                            Layout.fillWidth: true; height: 25; color: colorSurfaceAlt
                            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 2; color: colorBorder }
                            Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: "Showing " + tableViewList.count + " asset records"; color: colorTextDim; font.pixelSize: 11 }
                        }
                    }
                }

                // === PEOPLE SEARCH RESULTS ===
                Rectangle
                {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    visible: searchMode === "people"
                    radius: 12; color: colorSurface; border.color: colorBorder

                    ColumnLayout
                    {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle
                        {
                            Layout.fillWidth: true; height: 46; color: colorSurfaceAlt; radius: 12

                            RowLayout
                            {
                                anchors.fill: parent
                                anchors.leftMargin: 16; anchors.rightMargin: 16
                                spacing: 10

                                Text
                                {
                                    text: txtSearch.text.trim() === ""
                                          ? "Type a name to search assigned units"
                                          : personResults.length + " unit" + (personResults.length !== 1 ? "s" : "") +
                                            " found for \"" + txtSearch.text.trim() + "\""
                                    color: colorTextDim; font.pixelSize: 12; font.bold: true
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        ScrollView
                        {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ListView
                            {
                                id: personResultsList
                                anchors.fill: parent
                                model: personResults
                                spacing: 10
                                boundsBehavior: Flickable.StopAtBounds

                                header: Item { width: 1; height: 6 }

                                footer: Column
                                {
                                    width: personResultsList.width

                                    Text
                                    {
                                        x: 15
                                        width: parent.width - 30
                                        visible: txtSearch.text.trim() !== "" && personResults.length === 0
                                        text: "No units found assigned to \"" + txtSearch.text.trim() + "\""
                                        color: colorTextFaint; font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        topPadding: 30
                                    }

                                    Item { width: 1; height: 10 }
                                }

                                delegate: Item
                                {
                                    id: personCardRoot
                                    width: personResultsList.width
                                    height: personCardCol.implicitHeight + personCardCol.anchors.topMargin + 14

                                    Rectangle
                                    {
                                        x: 15
                                        width: parent.width - 30
                                        height: parent.height
                                        radius: 12; color: colorSurface; border.color: colorBorder; border.width: 1
                                    }

                                    Rectangle
                                    {
                                        x: 15
                                        width: 3; height: parent.height - 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: 2
                                        color: modelData.status === "Active" ? colorTeal : modelData.status === "Maintenance" ? colorOrange : colorBlue
                                    }

                                    ColumnLayout
                                    {
                                        id: personCardCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.topMargin: 14
                                        anchors.leftMargin: 35
                                        anchors.rightMargin: 29
                                        spacing: 6

                                        RowLayout
                                        {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Rectangle
                                            {
                                                width: 36; height: 36; radius: 10
                                                color: colorSurfaceActive; border.color: colorAccent; border.width: 1
                                                Image
                                                {
                                                    anchors.centerIn: parent
                                                    width: 20; height: 20
                                                    source: window.categoryIconSource(modelData.asset_category)
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true; mipmap: true; asynchronous: true
                                                }
                                            }

                                            ColumnLayout
                                            {
                                                Layout.fillWidth: true; spacing: 2
                                                Text { text: modelData.asset_name; color: colorTextPrimary; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                                Text { text: modelData.asset_category + " · " + modelData.asset_brand + " " + modelData.asset_model; color: colorTextDim; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }

                                            Rectangle
                                            {
                                                height: 20; radius: 10
                                                color: modelData.status === "Active" ? colorTealBg : modelData.status === "Maintenance" ? colorOrangeBg : colorBlueBg
                                                border.color: modelData.status === "Active" ? colorTeal : modelData.status === "Maintenance" ? colorOrange : colorBlue
                                                border.width: 1
                                                implicitWidth: pStatusText.implicitWidth + 14
                                                Text { id: pStatusText; anchors.centerIn: parent; text: modelData.status; color: modelData.status === "Active" ? colorTeal : modelData.status === "Maintenance" ? colorOrange : colorBlue; font.pixelSize: 10; font.bold: true }
                                            }
                                        }

                                        Rectangle { Layout.fillWidth: true; height: 1; color: colorBorder; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                                        RowLayout
                                        {
                                            Layout.fillWidth: true
                                            spacing: 16

                                            Column
                                            {
                                                spacing: 2
                                                Text { text: "ASSIGNED TO"; color: colorTextMuted; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                                                Text { text: modelData.assigned_to; color: colorAccentBright; font.pixelSize: 12; font.bold: true }
                                            }

                                            Column
                                            {
                                                spacing: 2
                                                Text { text: "UNIT ID"; color: colorTextMuted; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                                                Text { text: modelData.asset_unit_id; color: colorAccent; font.pixelSize: 11; font.bold: true; font.family: "monospace" }
                                            }

                                            Column
                                            {
                                                spacing: 2
                                                Text { text: "LOCATION"; color: colorTextMuted; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                                                Text { text: modelData.asset_location; color: colorTeal; font.pixelSize: 11; font.bold: true }
                                            }

                                            Column
                                            {
                                                spacing: 2
                                                Text { text: "ASSIGNED DATE"; color: colorTextMuted; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                                                Text { text: modelData.assigned_date; color: colorTextDim; font.pixelSize: 11 }
                                            }

                                            Item { Layout.fillWidth: true }
                                        }

                                        Item { Layout.fillWidth: true; height: 8 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ===
        // RIGHT SIDEBAR — TOGGLE + DETAIL PANEL
        // ===
        Rectangle
        {
            Layout.fillHeight: true; width: 28; color: "transparent"
            Rectangle
            {
                anchors.centerIn: parent; width: 28; height: 72; radius: 8
                color: toggleTabMouse.containsMouse ? colorSurfaceActive : colorSurface
                border.color: toggleTabMouse.containsMouse ? colorAccent : colorBorder; border.width: 1
                Behavior on color        { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Column { anchors.centerIn: parent; spacing: 5
                    Repeater { model: 3; Rectangle { width: 4; height: 4; radius: 2; anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined; color: toggleTabMouse.containsMouse ? colorAccent : colorTextFaint; Behavior on color { ColorAnimation { duration: 120 } } } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: isDetailPanelOpen ? "›" : "‹"; color: toggleTabMouse.containsMouse ? colorAccent : colorTextDim; font.pixelSize: 16; font.bold: true; Behavior on color { ColorAnimation { duration: 120 } } }
                }

                MouseArea { id: toggleTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: isDetailPanelOpen = !isDetailPanelOpen }
            }
        }

        Rectangle
        {
            id: detailPanel
            Layout.fillHeight: true
            Layout.preferredWidth: isDetailPanelOpen ? 340 : 0
            color: colorSurface; border.color: colorBorder
            border.width: isDetailPanelOpen ? 1 : 0; clip: true
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            readonly property var asset:
            {
                for (var i = 0; i < window.assetList.length; i++)
                    if (window.assetList[i].id === selectedAssetId)
                        return window.assetList[i]
                return null
            }

            function categoryColor(cat)
            {
                if (cat === "Laptop")  return colorAccent
                if (cat === "Desktop") return colorTeal
                if (cat === "Storage") return colorBlue
                if (cat === "Printer") return colorOrange
                if (cat === "Network") return colorGold
                var palette = window.isDarkMode
                              ? ["#e39ac0","#5ecfc0","#e3c15a","#8fcf7a","#e38a8a","#8ab0e3"]
                              : ["#b23b7a","#0f9d8a","#b08a1e","#4f9d3b","#b2453b","#3b6fb2"]
                var hash = 0
                for (var i = 0; i < cat.length; i++) hash = (hash * 31 + cat.charCodeAt(i)) & 0xffff
                return palette[hash % palette.length]
            }

            function startEditAsset()
            {
                if (!detailPanel.asset) return
                asset_name_text.text          = detailPanel.asset.asset_name       || ""
                asset_brand_text.text         = detailPanel.asset.asset_brand       || ""
                asset_model_text.text         = detailPanel.asset.asset_model       || ""
                asset_number_text.text        = String(detailPanel.asset.total_quantity || "")
                asset_serial_number_text.text = detailPanel.asset.serial_number     || ""
                asset_specs_text.text         = detailPanel.asset.asset_specs       || ""
                asset_Note_text.text          = detailPanel.asset.notes             || ""

                var ci = asset_category_combobox.find(detailPanel.asset.asset_category)
                if (ci >= 0) { asset_category_combobox.currentIndex = ci }
                else
                {
                    var xi = asset_category_combobox.find("Custom Category")
                    if (xi >= 0) asset_category_combobox.currentIndex = xi
                    asset_custom_category_text.text = detailPanel.asset.asset_category
                }

                isEditMode     = true
                editingAssetId = detailPanel.asset.id
                isAddFormOpen  = true
            }

            ColumnLayout
            {
                anchors.fill: parent; spacing: 0
                visible: isDetailPanelOpen

                Rectangle
                {
                    Layout.fillWidth: true; height: 58; color: colorSurface
                    RowLayout
                    {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 10
                        Rectangle { width: 32; height: 32; radius: 8; color: colorSurfaceActive; border.color: colorBorderStrong; border.width: 1; Image { anchors.centerIn: parent; width: 18; height: 18; source: "qrc:/icons/shield.png"; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true } }
                        Column
                        {
                            spacing: 3; Layout.fillWidth: true
                            Text { text: "Asset Details"; color: colorTextPrimary; font.bold: true; font.pixelSize: 13 }
                            Text { text: detailPanel.asset ? detailPanel.asset.asset_name : "No selection"; color: colorTextDim; font.pixelSize: 10; elide: Text.ElideRight; width: 180 }
                        }
                        Rectangle
                        {
                            width: 26; height: 26; radius: 6
                            color: closePanelMouse.containsMouse ? colorErrorBg : "transparent"
                            border.color: closePanelMouse.containsMouse ? colorError : "transparent"; border.width: 1
                            Behavior on color        { ColorAnimation { duration: 80 } }
                            Behavior on border.color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "✕"; color: closePanelMouse.containsMouse ? colorError : colorTextDim; font.pixelSize: 11; Behavior on color { ColorAnimation { duration: 80 } } }
                            MouseArea { id: closePanelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: isDetailPanelOpen = false }
                        }
                    }

                }

                Rectangle { Layout.fillWidth: true; height: 1; color: colorBorder }

                Item
                {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: detailPanel.asset === null
                    Column { anchors.centerIn: parent; spacing: 14
                        Image { anchors.horizontalCenter: parent.horizontalCenter; width: 48; height: 48; source: "qrc:/icons/clipboard.png"; fillMode: Image.PreserveAspectFit; opacity: 0.35; smooth: true; mipmap: true; asynchronous: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No asset selected"; color: colorTextFaint; font.pixelSize: 14; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Click any row to view details"; color: colorBorderStrong; font.pixelSize: 11 }
                    }
                }

                RowLayout
                {
                    Layout.fillWidth: true
                    visible: detailPanel.asset !== null
                    spacing: 0
                    Layout.margins: 10

                    Rectangle
                    {
                        Layout.fillWidth: true; height: 34; radius: 8
                        color: detailPanelTab === "overview" ? colorSurfaceActive : "transparent"
                        Text { anchors.centerIn: parent; text: "Overview"; color: detailPanelTab === "overview" ? colorAccent : colorTextDim; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: detailPanelTab = "overview" }
                    }
                    Rectangle
                    {
                        Layout.fillWidth: true; height: 34; radius: 8
                        color: detailPanelTab === "units" ? colorSurfaceActive : "transparent"
                        RowLayout
                        {
                            anchors.centerIn: parent; spacing: 5
                            Text { text: "Units"; color: detailPanelTab === "units" ? colorAccent : colorTextDim; font.pixelSize: 11; font.bold: true }
                            Rectangle
                            {
                                width: unitCountText.implicitWidth + 10; height: 16; radius: 8; color: colorSurfaceActive
                                Text { id: unitCountText; anchors.centerIn: parent; text: window.unitList.length; color: colorAccent; font.pixelSize: 9; font.bold: true }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: detailPanelTab = "units" }
                    }
                }

                // === OVERVIEW TAB ===
                ScrollView
                {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: detailPanel.asset !== null && detailPanelTab === "overview"
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout
                    {
                        width: detailPanel.width - 24; x: 12; spacing: 10
                        Item { width: 1; height: 4 }

                        Rectangle
                        {
                            Layout.fillWidth: true; height: 86; radius: 12; color: colorSurface; border.color: colorBorder; border.width: 1
                            Rectangle { width: 3; height: 44; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; radius: 2; color: detailPanel.asset ? detailPanel.categoryColor(detailPanel.asset.asset_category) : colorAccent }

                            RowLayout
                            {
                                anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 14; anchors.topMargin: 14; anchors.bottomMargin: 14; spacing: 14
                                Rectangle
                                {
                                    width: 46; height: 46; radius: 12; color: colorSurfaceActive
                                    border.color: detailPanel.asset ? detailPanel.categoryColor(detailPanel.asset.asset_category) : colorAccent; border.width: 1
                                    Image
                                    {
                                        anchors.centerIn: parent
                                        width: 26; height: 26
                                        source: detailPanel.asset ? window.categoryIconSource(detailPanel.asset.asset_category) : "qrc:/icons/package.png"
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true; mipmap: true; asynchronous: true
                                    }
                                }
                                ColumnLayout
                                {
                                    Layout.fillWidth: true; spacing: 7
                                    CopyableText { text: detailPanel.asset ? detailPanel.asset.asset_name : ""; color: colorTextPrimary; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true }
                                    Rectangle
                                    {
                                        height: 20; radius: 10; color: colorSurfaceActive; border.color: colorBorderStrong; border.width: 1
                                        implicitWidth: catText.implicitWidth + 16
                                        Text { id: catText; anchors.centerIn: parent; text: detailPanel.asset ? detailPanel.asset.asset_category : ""; color: detailPanel.asset ? detailPanel.categoryColor(detailPanel.asset.asset_category) : colorAccent; font.pixelSize: 10; font.bold: true }
                                    }
                                }
                            }
                        }

                        component InfoRow: ColumnLayout
                        {
                            property string rowLabel: ""
                            property string rowValue: "—"
                            property color  rowValueColor: colorTextPrimary
                            property bool   isLast: false
                            Layout.fillWidth: true; spacing: 0
                            RowLayout
                            {
                                Layout.fillWidth: true
                                height: 38

                                Text {
                                    text: rowLabel
                                    color: colorTextDim
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 108
                                }

                                TextInput
                                {
                                    text: rowValue !== "" ? rowValue : "—"
                                    color: rowValueColor
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    readOnly: true
                                    selectByMouse: true
                                    persistentSelection: true
                                    selectionColor: colorAccent
                                    selectedTextColor: colorSurface

                                    cursorVisible: false

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.IBeamCursor
                                        acceptedButtons: Qt.NoButton
                                    }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: colorBorder; visible: !isLast }
                        }

                        Text { text: "ASSET DETAILS"; color: colorTextMuted; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; leftPadding: 2 }
                        Rectangle
                        {
                            Layout.fillWidth: true; height: detailsCol.implicitHeight + 8; radius: 12; color: colorSurface; border.color: colorBorder; border.width: 1
                            ColumnLayout { id: detailsCol; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 4; spacing: 8
                                InfoRow { rowLabel: "Brand";       rowValue: detailPanel.asset ? (detailPanel.asset.asset_brand || "—") : "—" }
                                InfoRow { rowLabel: "Model";       rowValue: detailPanel.asset ? (detailPanel.asset.asset_model || "—") : "—" }
                                InfoRow { rowLabel: "Serial No.";  rowValue: detailPanel.asset ? detailPanel.asset.serial_number : "—" }
                                InfoRow { rowLabel: "Specs";       rowValue: detailPanel.asset ? (detailPanel.asset.asset_specs || "—") : "—" }
                                InfoRow { rowLabel: "Notes";       rowValue: detailPanel.asset ? (detailPanel.asset.notes || "—") : "—" }
                                InfoRow { rowLabel: "Created";     rowValue: detailPanel.asset ? (detailPanel.asset.created_at || "—") : "—"; rowValueColor: colorTextDim; isLast: true }
                            }
                        }

                        Text { text: "INVENTORY"; color: colorTextMuted; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; leftPadding: 2 }
                        Rectangle
                        {
                            Layout.fillWidth: true; height: invCol.implicitHeight + 8; radius: 12; color: colorSurface; border.color: colorBorder; border.width: 1
                            ColumnLayout { id: invCol; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 4; spacing: 8
                                InfoRow { rowLabel: "Total quantity"; rowValue: detailPanel.asset ? String(detailPanel.asset.total_quantity) : "—"; rowValueColor: colorTextPrimary }
                                InfoRow { rowLabel: "Assigned";       rowValue: detailPanel.asset ? String(detailPanel.asset.assigned_quantity) : "—"; rowValueColor: colorOrange }
                                InfoRow { rowLabel: "Pending";        rowValue: detailPanel.asset ? String(detailPanel.asset.pending_quantity) : "—"; rowValueColor: colorTeal; isLast: true }
                            }
                        }

                        Text { text: "ACTIONS"; color: colorTextMuted; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; leftPadding: 2 }
                        RowLayout
                        {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle
                            {
                                Layout.fillWidth: true; height: 38; radius: 9
                                color: editMouse.containsMouse ? colorSurfaceActive : colorSurface
                                border.color: editMouse.containsMouse ? colorAccent : colorBorder; border.width: 1
                                Behavior on color        { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                                RowLayout { anchors.centerIn: parent; spacing: 7
                                    Image { width: 8; height: 8; source: "qrc:/icons/edit.png"; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true }
                                    Text { text: "Edit"; color: editMouse.containsMouse ? colorAccentDeep : colorAccent; font.pixelSize: 12; font.bold: true; Behavior on color { ColorAnimation { duration: 100 } } }
                                }
                                MouseArea { id: editMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: detailPanel.startEditAsset() }
                            }

                            Rectangle
                            {
                                Layout.fillWidth: true; height: 38; radius: 9
                                color: deleteMouse.containsMouse ? colorErrorBg : colorSurface
                                border.color: deleteMouse.containsMouse ? colorError : colorBorder; border.width: 1
                                Behavior on color        { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                                RowLayout { anchors.centerIn: parent; spacing: 7
                                    Image { width: 8; height: 8; source: "qrc:/icons/delete.png"; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true }
                                    Text { text: "Delete"; color: deleteMouse.containsMouse ? colorError : colorTextDim; font.pixelSize: 12; font.bold: true; Behavior on color { ColorAnimation { duration: 100 } } }
                                }
                                MouseArea
                                {
                                    id: deleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                    {
                                        if (detailPanel.asset)
                                        {
                                            if (inventory_backend.delete_asset(detailPanel.asset.id))
                                            {
                                                selectedAssetId = -1
                                                refreshEverything()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { width: 1; height: 10 }
                    }
                }

                // === UNITS TAB ====
                ScrollView
                {
                    id: unitsTabRoot
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: detailPanel.asset !== null && detailPanelTab === "units"
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    property int    lockedAssetId:   -1
                    property string lockedAssetName: ""

                    function resetForm()
                    {
                        unitAssignedToField.text = ""
                        unitLocationField.text   = ""
                        unitNotesField.text      = ""
                        unitStatusCombo.currentIndex = 0
                        isUnitEditMode = false
                        editingUnitId  = -1
                    }

                    ColumnLayout
                    {
                        width: detailPanel.width - 24; x: 12; spacing: 10
                        Item { width: 1; height: 4 }

                        Rectangle
                        {
                            Layout.fillWidth: true; height: 38; radius: 9
                            visible: !isAssignFormOpen
                            color: assignMouse.containsMouse ? colorSurfaceActive : colorSurface
                            border.color: assignMouse.containsMouse ? colorAccent : colorBorder; border.width: 1
                            enabled: detailPanel.asset && detailPanel.asset.pending_quantity > 0
                            opacity: enabled ? 1.0 : 0.4
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout
                            {
                                anchors.centerIn: parent; spacing: 7
                                Text { text: "+"; color: colorAccent; font.pixelSize: 15; font.bold: true }
                                Text
                                {
                                    text: (detailPanel.asset && detailPanel.asset.pending_quantity > 0)
                                          ? "Assign new unit (" + detailPanel.asset.pending_quantity + " pending)"
                                          : "No pending units"
                                    color: colorAccent; font.pixelSize: 11; font.bold: true
                                }
                            }

                            MouseArea
                            {
                                id: assignMouse
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked:
                                {
                                    if (!detailPanel.asset) return
                                    unitsTabRoot.lockedAssetId   = detailPanel.asset.id
                                    unitsTabRoot.lockedAssetName = detailPanel.asset.asset_name
                                    unitsTabRoot.resetForm()
                                    isAssignFormOpen = true
                                }
                            }
                        }

                        Rectangle
                        {
                            Layout.fillWidth: true
                            visible: isAssignFormOpen
                            radius: 12
                            color: colorSurface
                            border.color: isUnitEditMode ? colorOrange : colorAccent
                            border.width: 1.5
                            implicitHeight: assignFormCol.implicitHeight + 24

                            ColumnLayout
                            {
                                id: assignFormCol
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 12
                                spacing: 8

                                Text { text: isUnitEditMode ? "Edit assignment" : "Assign new unit"; color: isUnitEditMode ? colorOrange : colorAccent; font.bold: true; font.pixelSize: 11 }

                                Rectangle
                                {
                                    Layout.fillWidth: true; height: 26; radius: 7; color: colorSurfaceAlt; border.color: colorTeal; border.width: 1
                                    Text
                                    {
                                        anchors.centerIn: parent
                                        text: "🔒 " + unitsTabRoot.lockedAssetName
                                        color: colorTeal; font.pixelSize: 10; font.bold: true
                                    }
                                }

                                ColumnLayout
                                {
                                    Layout.fillWidth: true; spacing: 4
                                    Text { text: "Assigned to *"; color: unitAssignedToField.empty_box ? colorError : colorAccent; font.pixelSize: 10; font.bold: true }
                                    TextField
                                    {
                                        id: unitAssignedToField
                                        property bool empty_box: false
                                        Layout.fillWidth: true; height: 32
                                        placeholderText: "Ajay Lamsar"; color: colorTextPrimary; font.pixelSize: 11
                                        background: Rectangle { color: colorSurfaceAlt; border.color: unitAssignedToField.empty_box ? colorError : colorBorder; radius: 7 }
                                    }
                                }

                                ColumnLayout
                                {
                                    Layout.fillWidth: true; spacing: 4
                                    Text { text: "Location *"; color: unitLocationField.empty_box ? colorError : colorAccent; font.pixelSize: 10; font.bold: true }
                                    TextField
                                    {
                                        id: unitLocationField
                                        property bool empty_box: false
                                        Layout.fillWidth: true; height: 32
                                        placeholderText: "Devloper-Room"; color: colorTextPrimary; font.pixelSize: 11
                                        background: Rectangle { color: colorSurfaceAlt; border.color: unitLocationField.empty_box ? colorError : colorBorder; radius: 7 }
                                    }
                                }

                                ColumnLayout
                                {
                                    Layout.fillWidth: true; spacing: 4
                                    Text { text: "Status"; color: colorAccent; font.pixelSize: 10; font.bold: true }
                                    ComboBox
                                    {
                                        id: unitStatusCombo
                                        Layout.fillWidth: true
                                        model: ["Active", "Maintenance", "Inactive"]

                                        function sColor(s) { if (s === "Active") return colorTeal; if (s === "Maintenance") return colorOrange; return colorBlue }

                                        background: Rectangle { color: colorSurfaceAlt; border.color: colorBorder; radius: 7; implicitHeight: 32 }
                                        contentItem: RowLayout
                                        {
                                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 6
                                            Rectangle { width: 7; height: 7; radius: 4; Layout.alignment: Qt.AlignVCenter; color: unitStatusCombo.sColor(unitStatusCombo.currentText) }
                                            Text { text: unitStatusCombo.displayText; color: unitStatusCombo.sColor(unitStatusCombo.currentText); font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; verticalAlignment: Text.AlignVCenter }
                                        }
                                        popup: Popup
                                        {
                                            y: unitStatusCombo.height + 4; width: unitStatusCombo.width; padding: 4
                                            background: Rectangle { color: colorSurface; border.color: colorBorder; border.width: 1; radius: 10 }
                                            contentItem: ListView { implicitHeight: contentHeight; model: unitStatusCombo.delegateModel; clip: true }
                                        }
                                        delegate: ItemDelegate
                                        {
                                            width: unitStatusCombo.width - 8
                                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                            highlighted: unitStatusCombo.highlightedIndex === index
                                            background: Rectangle { color: parent.highlighted ? colorSurfaceActive : "transparent"; radius: 7 }
                                            contentItem: RowLayout
                                            {
                                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                                Rectangle { width: 7; height: 7; radius: 4; Layout.alignment: Qt.AlignVCenter; color: unitStatusCombo.sColor(modelData) }
                                                Text { text: modelData; color: unitStatusCombo.sColor(modelData); font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                            }
                                        }
                                    }
                                }

                                ColumnLayout
                                {
                                    Layout.fillWidth: true; spacing: 4
                                    Text { text: "Notes"; color: colorTextDim; font.pixelSize: 10; font.bold: true }
                                    TextField
                                    {
                                        id: unitNotesField
                                        Layout.fillWidth: true; height: 32
                                        placeholderText: "Any additional notes"; color: colorTextPrimary; font.pixelSize: 11
                                        background: Rectangle { color: colorSurfaceAlt; border.color: colorBorder; radius: 7 }
                                    }
                                }

                                RowLayout
                                {
                                    Layout.fillWidth: true; spacing: 8
                                    Item { Layout.fillWidth: true }

                                    Button
                                    {
                                        implicitWidth: 80; implicitHeight: 32
                                        text: "Cancel"
                                        background: Rectangle { color: "transparent"; border.color: colorBorder; border.width: 1; radius: 8 }
                                        contentItem: Text { text: parent.text; color: colorTextDim; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked:
                                        {
                                            isAssignFormOpen = false
                                            unitsTabRoot.resetForm()
                                            unitsTabRoot.lockedAssetId   = -1
                                            unitsTabRoot.lockedAssetName = ""
                                        }
                                    }

                                    Button
                                    {
                                        implicitWidth: 130; implicitHeight: 32
                                        text: isUnitEditMode ? "Save" : "Assign"
                                        background: Rectangle { color: isUnitEditMode ? colorOrange : colorAccent; radius: 8 }
                                        contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked:
                                        {
                                            unitAssignedToField.empty_box = unitAssignedToField.text.trim() === ""
                                            unitLocationField.empty_box   = unitLocationField.text.trim() === ""
                                            if (unitAssignedToField.empty_box || unitLocationField.empty_box) return
                                            if (unitsTabRoot.lockedAssetId <= 0) return

                                            var unitData =
                                                    {
                                                "asset_ref_id":   unitsTabRoot.lockedAssetId,
                                                "assigned_to":    unitAssignedToField.text.trim(),
                                                "asset_location": unitLocationField.text.trim(),
                                                "status":         unitStatusCombo.currentText,
                                                "notes":          unitNotesField.text.trim()
                                            }

                                            var ok = false
                                            if (isUnitEditMode && editingUnitId > 0)
                                                ok = inventory_backend.update_unit(editingUnitId, unitData)
                                            else
                                                ok = inventory_backend.assign_unit(unitData)

                                            if (ok)
                                            {
                                                isAssignFormOpen = false
                                                unitsTabRoot.resetForm()
                                                unitsTabRoot.lockedAssetId   = -1
                                                unitsTabRoot.lockedAssetName = ""
                                                refreshEverything()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Repeater
                        {
                            model: window.unitList

                            Item
                            {
                                id: unitCardRoot
                                Layout.fillWidth: true
                                implicitHeight: unitCardCol.height + unitCardCol.anchors.topMargin + 10

                                Rectangle
                                {
                                    anchors.fill: parent
                                    radius: 10; color: colorSurface; border.color: colorBorder; border.width: 1
                                }

                                Rectangle
                                {
                                    width: 3; height: parent.height - 16
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    radius: 2
                                    color: modelData.status === "Active" ? colorTeal : modelData.status === "Maintenance" ? colorOrange : colorBlue
                                }

                                ColumnLayout
                                {
                                    id: unitCardCol
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.topMargin: 12
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 12
                                    spacing: 6

                                    RowLayout
                                    {
                                        Layout.fillWidth: true
                                        Rectangle
                                        {
                                            height: 20; radius: 6; color: colorSurfaceActive; border.color: colorBorderStrong; border.width: 1
                                            implicitWidth: unitIdText.implicitWidth + 14
                                            CopyableText { id: unitIdText; anchors.centerIn: parent; text: modelData.asset_unit_id; color: colorAccent; font.pixelSize: 10; font.bold: true; font.family: "monospace" }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle
                                        {
                                            height: 20; radius: 10
                                            color: modelData.status === "Active" ? colorTealBg : modelData.status === "Maintenance" ? colorOrangeBg : colorBlueBg
                                            border.color: modelData.status === "Active" ? colorTeal : modelData.status === "Maintenance" ? colorOrange : colorBlue
                                            border.width: 1
                                            implicitWidth: statusText.implicitWidth + 14
                                            Text { id: statusText; anchors.centerIn: parent; text: modelData.status; color: modelData.status === "Active" ? colorTeal : modelData.status === "Maintenance" ? colorOrange : colorBlue; font.pixelSize: 10; font.bold: true }
                                        }
                                    }

                                    CopyableText { text: modelData.assigned_to;    color: colorTextPrimary; font.pixelSize: 12; font.bold: true }
                                    CopyableText { text: "📍 " + modelData.asset_location; color: colorTeal; font.pixelSize: 11 }
                                    CopyableText { text: "Assigned: " + modelData.assigned_date; color: colorTextDim; font.pixelSize: 10 }
                                    CopyableText { text: "Returned: " + modelData.return_date; color: colorError; font.pixelSize: 10; visible: modelData.status === "Inactive" && !!modelData.return_date }

                                    RowLayout
                                    {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 4
                                        spacing: 6

                                        Rectangle
                                        {
                                            Layout.fillWidth: true; height: 28; radius: 7
                                            color: unitEditMouse.containsMouse ? colorSurfaceActive : colorSurface
                                            border.color: colorBorder; border.width: 1
                                            Text { anchors.centerIn: parent; text: "Edit"; color: colorAccent; font.pixelSize: 10; font.bold: true }
                                            MouseArea
                                            {
                                                id: unitEditMouse
                                                anchors.fill: parent
                                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked:
                                                {
                                                    unitAssignedToField.text = modelData.assigned_to    || ""
                                                    unitLocationField.text   = modelData.asset_location || ""
                                                    unitNotesField.text      = modelData.notes          || ""
                                                    var si = unitStatusCombo.find(modelData.status)
                                                    unitStatusCombo.currentIndex = si >= 0 ? si : 0
                                                    isUnitEditMode = true
                                                    editingUnitId  = modelData.id

                                                    unitsTabRoot.lockedAssetId   = modelData.asset_ref_id
                                                    unitsTabRoot.lockedAssetName = detailPanel.asset ? detailPanel.asset.asset_name : ""

                                                    isAssignFormOpen = true
                                                }
                                            }
                                        }

                                        Rectangle
                                        {
                                            Layout.fillWidth: true; height: 28; radius: 7
                                            visible: modelData.status !== "Inactive"
                                            color: returnMouse.containsMouse ? colorTealBg : colorSurface
                                            border.color: colorBorder; border.width: 1
                                            Text { anchors.centerIn: parent; text: "Return"; color: colorTeal; font.pixelSize: 10; font.bold: true }
                                            MouseArea
                                            {
                                                id: returnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (inventory_backend.return_unit(modelData.id)) refreshEverything() }
                                            }
                                        }

                                        Rectangle
                                        {
                                            Layout.fillWidth: true; height: 28; radius: 7
                                            color: unitDeleteMouse.containsMouse ? colorErrorBg : colorSurface
                                            border.color: colorBorder; border.width: 1
                                            Text { anchors.centerIn: parent; text: "Delete"; color: colorError; font.pixelSize: 10; font.bold: true }
                                            MouseArea
                                            {
                                                id: unitDeleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (inventory_backend.delete_unit(modelData.id)) refreshEverything() }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true; height: 6 }
                                }
                            }
                        }

                        Text
                        {
                            Layout.fillWidth: true
                            visible: window.unitList.length === 0 && !isAssignFormOpen
                            text: "No units assigned yet"
                            color: colorTextFaint; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 20
                        }

                        Item { width: 1; height: 10 }
                    }
                }
            }
        }
    }
}

cmake_minimum_required(VERSION 3.16)

project(Smart_Resources_Manager VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable Qt automoc/autorcc (CRITICAL!)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find Qt6 components
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Sql)

qt_standard_project_setup()

# Define source files
set(SOURCES
    main.cpp
    database_manager.h
    database_manager.cpp
    inventory_manager.h
    inventory_manager.cpp
    resources.qrc
)

# Qt Quick resources (QML)
qt_add_executable(${PROJECT_NAME}
    ${SOURCES}
    # icons/logo.png
)

# Link the Qt6 libraries
target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Sql

)

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

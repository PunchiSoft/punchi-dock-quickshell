cmake_minimum_required(VERSION 3.22)
project(punchi-shell VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Quick Qml)
find_package(KF6KIO REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6WindowSystem 6.19 REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WaylandClient REQUIRED IMPORTED_TARGET wayland-client)
qt_standard_project_setup()
qt_policy(SET QTP0001 NEW)
qt_add_qml_module(punchikde
    URI Punchi.Kde
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/Punchi/Kde
    SOURCES adapters/kde/native/desktoplauncher.h adapters/kde/native/desktoplauncher.cpp
        adapters/kde/native/desktopentry.h
        adapters/kde/native/recentdocuments.h adapters/kde/native/recentdocuments.cpp
        adapters/kde/native/fileplaces.h adapters/kde/native/fileplaces.cpp
        adapters/kde/native/applicationcatalog.h adapters/kde/native/applicationcatalog.cpp
        adapters/kde/native/runningapplications.h adapters/kde/native/runningapplications.cpp)
target_link_libraries(punchikde PRIVATE Qt6::Quick KF6::KIOGui KF6::KIOFileWidgets KF6::Service KF6::WindowSystem Plasma::ActivitiesStats)
target_include_directories(punchikde PRIVATE ${CMAKE_SOURCE_DIR}/adapters/kde/native)
add_executable(punchi-window-state adapters/kde/window-state/main.cpp
    adapters/kde/window-state/registration.cpp)
target_link_libraries(punchi-window-state PRIVATE Qt6::Gui Qt6::Qml KF6::Service PkgConfig::WaylandClient)
include(CTest)

if(BUILD_TESTING)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    find_program(QMLLINT_EXECUTABLE NAMES qmllint qmllint6
        HINTS /usr/lib64/qt6/bin /usr/lib/qt6/bin REQUIRED)
    find_program(QMLTESTRUNNER_EXECUTABLE NAMES qmltestrunner qmltestrunner6
        HINTS /usr/lib64/qt6/bin /usr/lib/qt6/bin REQUIRED)

    add_test(NAME qml_lint COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/validate-qml.py ${QMLLINT_EXECUTABLE})
    add_test(NAME dock_components COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${QMLTESTRUNNER_EXECUTABLE} -input ${CMAKE_SOURCE_DIR}/tests/qml)
    find_program(QUICKSHELL_EXECUTABLE NAMES qs REQUIRED)
    find_program(DBUS_RUN_SESSION_EXECUTABLE NAMES dbus-run-session REQUIRED)
    add_test(NAME application_launch COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/launch_runtime_test.py)
    add_test(NAME popup_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/popup_runtime_test.py)
    add_test(NAME recent_documents COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/recent_runtime_test.py)
    add_test(NAME places_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/places_runtime_test.py)
    add_test(NAME application_items COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/application_items_test.py)
    add_test(NAME settings_theme COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/settings_theme_runtime_test.py)
    add_test(NAME configuration_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/configuration_runtime_test.py)
    add_test(NAME settings_reload COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --session --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/settings_reload_test.py)
    add_test(NAME window_capability COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/tests/window_capability_test.py)
    add_test(NAME project_foundation COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/tests/foundation_test.py)
    set_tests_properties(qml_lint dock_components application_launch popup_runtime recent_documents places_runtime application_items settings_theme configuration_runtime settings_reload window_capability project_foundation PROPERTIES TIMEOUT 45)
endif()

cmake_minimum_required(VERSION 3.22)
project(punchi-shell VERSION 0.1.12 LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Quick Qml DBus)
find_package(KF6KIO REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6WindowSystem 6.19 REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WaylandClient REQUIRED IMPORTED_TARGET wayland-client)
find_program(WAYLAND_SCANNER_EXECUTABLE wayland-scanner REQUIRED)
set(PROTOCOL_DIR ${CMAKE_BINARY_DIR}/protocols)
file(MAKE_DIRECTORY ${PROTOCOL_DIR})
set(EDGE_PROTOCOL_SOURCES)
foreach(protocol kde-screen-edge-v1 wlr-layer-shell-unstable-v1 xdg-shell)
    set(protocol_xml ${CMAKE_SOURCE_DIR}/adapters/kde/protocols/${protocol}.xml)
    foreach(kind client-header server-header private-code)
        if(kind STREQUAL "private-code")
            set(output ${PROTOCOL_DIR}/${protocol}.c)
        elseif(kind STREQUAL "client-header")
            set(output ${PROTOCOL_DIR}/${protocol}-client.h)
        else()
            set(output ${PROTOCOL_DIR}/${protocol}-server.h)
        endif()
        add_custom_command(OUTPUT ${output}
            COMMAND ${WAYLAND_SCANNER_EXECUTABLE} ${kind} ${protocol_xml} ${output}
            DEPENDS ${protocol_xml} VERBATIM)
        list(APPEND EDGE_PROTOCOL_SOURCES ${output})
    endforeach()
endforeach()
add_library(punchi_edge_protocols STATIC ${EDGE_PROTOCOL_SOURCES})
set_target_properties(punchi_edge_protocols PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(punchi_edge_protocols PUBLIC ${PROTOCOL_DIR})
target_link_libraries(punchi_edge_protocols PUBLIC PkgConfig::WaylandClient)
qt_standard_project_setup()
qt_policy(SET QTP0001 NEW)
qt_add_qml_module(punchikde
    URI Punchi.Kde
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/Punchi/Kde
    SOURCES adapters/kde/native/desktoplauncher.h adapters/kde/native/desktoplauncher.cpp
        adapters/kde/native/popupblurcontroller.h adapters/kde/native/popupblurcontroller.cpp
        adapters/kde/native/iconthemerefresh.h adapters/kde/native/iconthemerefresh.cpp
        adapters/kde/native/foldercontents.h adapters/kde/native/foldercontents.cpp
        adapters/kde/native/desktopentry.h
        adapters/kde/native/recentdocuments.h adapters/kde/native/recentdocuments.cpp
        adapters/kde/native/fileplaces.h adapters/kde/native/fileplaces.cpp
        adapters/kde/native/applicationcatalog.h adapters/kde/native/applicationcatalog.cpp
        adapters/kde/native/dockitemcatalog.h adapters/kde/native/dockitemcatalog.cpp
        adapters/kde/native/trashstate.h adapters/kde/native/trashstate.cpp
        adapters/kde/native/dockapplicationsmodel.h adapters/kde/native/dockapplicationsmodel.cpp
        adapters/kde/native/runningapplications.h adapters/kde/native/runningapplications.cpp
        adapters/kde/native/windowvisibilitystate.h adapters/kde/native/windowvisibilitystate.cpp
        adapters/kde/native/windowactivation.h adapters/kde/native/windowactivation.cpp
        adapters/kde/native/autohideedge.h adapters/kde/native/autohideedge.cpp)
target_link_libraries(punchikde PRIVATE Qt6::Quick Qt6::DBus KF6::KIOGui KF6::KIOFileWidgets KF6::Service KF6::WindowSystem Plasma::ActivitiesStats)
target_include_directories(punchikde PRIVATE ${CMAKE_SOURCE_DIR}/adapters/kde/native)
target_link_libraries(punchikde PRIVATE punchi_edge_protocols)
add_executable(punchi-window-state adapters/kde/window-state/main.cpp
    adapters/kde/window-state/registration.cpp adapters/kde/window-state/windowactivation.cpp)
target_link_libraries(punchi-window-state PRIVATE Qt6::Gui Qt6::Qml KF6::Service KF6::WindowSystem PkgConfig::WaylandClient)
add_library(punchi_task_identity STATIC adapters/kde/window-state/taskidentity.cpp)
target_link_libraries(punchi_task_identity PUBLIC Qt6::Gui KF6::Service KF6::CoreAddons)
target_link_libraries(punchi-window-state PRIVATE punchi_task_identity)
qt_add_resources(punchi-window-state "window_models" PREFIX "/"
    FILES adapters/kde/window-state/WindowModels.qml)
include(CTest)

if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    add_executable(folder_contents_test tests/folder_contents_test.cpp adapters/kde/native/foldercontents.cpp)
    target_include_directories(folder_contents_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(folder_contents_test PRIVATE Qt6::Test Qt6::Widgets Qt6::Qml KF6::KIOFileWidgets)
    add_test(NAME folder_contents COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py $<TARGET_FILE:folder_contents_test>)
    set_tests_properties(folder_contents PROPERTIES TIMEOUT 45)
    add_executable(trash_state_test tests/trash_state_test.cpp
        adapters/kde/native/trashstate.cpp adapters/kde/native/dockitemcatalog.cpp
        adapters/kde/native/applicationcatalog.cpp adapters/kde/native/dockapplicationsmodel.cpp)
    target_include_directories(trash_state_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(trash_state_test PRIVATE Qt6::Test Qt6::Gui Qt6::Qml KF6::KIOCore KF6::Service)
    add_test(NAME trash_state COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py $<TARGET_FILE:trash_state_test>)
    set_tests_properties(trash_state PROPERTIES TIMEOUT 45)
    add_executable(task_identity_test tests/task_identity_test.cpp
        adapters/kde/window-state/windowactivation.cpp
        adapters/kde/native/applicationcatalog.cpp adapters/kde/native/dockapplicationsmodel.cpp)
    target_include_directories(task_identity_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(task_identity_test PRIVATE Qt6::Test Qt6::Qml Qt6::Quick punchi_task_identity)
    add_test(NAME task_identity COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/task_identity_test.py $<TARGET_FILE:task_identity_test>)
    set_tests_properties(task_identity PROPERTIES TIMEOUT 45)
    add_executable(dock_applications_test tests/dock_applications_test.cpp adapters/kde/native/dockapplicationsmodel.cpp)
    target_include_directories(dock_applications_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(dock_applications_test PRIVATE Qt6::Test Qt6::Gui Qt6::Qml KF6::Service)
    add_test(NAME dock_applications COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py -- $<TARGET_FILE:dock_applications_test>)
    add_executable(window_activation_test tests/window_activation_test.cpp
        adapters/kde/window-state/windowactivation.cpp
        adapters/kde/native/runningapplications.cpp adapters/kde/native/windowactivation.cpp
        adapters/kde/native/windowvisibilitystate.cpp)
    target_include_directories(window_activation_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(window_activation_test PRIVATE Qt6::Test Qt6::Gui Qt6::Qml KF6::Service)
    target_link_libraries(window_activation_test PRIVATE punchi_task_identity)
    target_compile_definitions(window_activation_test PRIVATE PUNCHI_TEST_BACKEND="$<TARGET_FILE:punchi-window-state>")
    add_executable(window_models_test tests/window_models_test.cpp)
    target_include_directories(window_models_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(window_models_test PRIVATE Qt6::Test Qt6::Gui Qt6::Qml KF6::Service)
    target_link_libraries(window_models_test PRIVATE punchi_task_identity)
    qt_add_resources(window_models_test "window_models_test_resource" PREFIX "/"
        FILES adapters/kde/window-state/WindowModels.qml)
    pkg_check_modules(WaylandServer REQUIRED IMPORTED_TARGET wayland-server)
    add_executable(autohide_edge_test tests/autohide_edge_test.cpp adapters/kde/native/autohideedge.cpp)
    target_include_directories(autohide_edge_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(autohide_edge_test PRIVATE Qt6::Test Qt6::Qml punchi_edge_protocols PkgConfig::WaylandServer)
    add_executable(running_state_test tests/running_state_test.cpp adapters/kde/native/runningapplications.cpp
        adapters/kde/native/windowvisibilitystate.cpp adapters/kde/native/windowactivation.cpp)
    target_include_directories(running_state_test PRIVATE ${CMAKE_SOURCE_DIR})
    target_link_libraries(running_state_test PRIVATE Qt6::Test Qt6::Gui Qt6::Qml KF6::Service)
    target_link_libraries(running_state_test PRIVATE punchi_task_identity)
    target_compile_definitions(running_state_test PRIVATE PUNCHI_TEST_BACKEND="$<TARGET_FILE:punchi-window-state>")
    find_program(QMLLINT_EXECUTABLE NAMES qmllint qmllint6
        HINTS /usr/lib64/qt6/bin /usr/lib/qt6/bin REQUIRED)
    find_program(QMLTESTRUNNER_EXECUTABLE NAMES qmltestrunner qmltestrunner6
        HINTS /usr/lib64/qt6/bin /usr/lib/qt6/bin REQUIRED)

    add_test(NAME qml_lint COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/validate-qml.py ${QMLLINT_EXECUTABLE})
    add_test(NAME dock_components COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${QMLTESTRUNNER_EXECUTABLE} -input ${CMAKE_SOURCE_DIR}/tests/qml)
    add_test(NAME folder_container COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/folder_container_test.py ${QMLTESTRUNNER_EXECUTABLE})
    set_tests_properties(folder_container PROPERTIES TIMEOUT 45)
    add_test(NAME autohide_edge COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py -- $<TARGET_FILE:autohide_edge_test>)
    set_tests_properties(autohide_edge PROPERTIES TIMEOUT 45)
    find_program(QUICKSHELL_EXECUTABLE NAMES qs REQUIRED)
    find_program(DBUS_RUN_SESSION_EXECUTABLE NAMES dbus-run-session REQUIRED)
    add_test(NAME icon_theme_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/icon_theme_runtime_test.py)
    set_tests_properties(icon_theme_runtime PROPERTIES TIMEOUT 45)
    add_test(NAME vertical_dock_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/vertical_dock_runtime_test.py)
    set_tests_properties(vertical_dock_runtime PROPERTIES TIMEOUT 45)
    add_test(NAME tooltip_theme_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/tooltip_theme_runtime_test.py)
    set_tests_properties(tooltip_theme_runtime PROPERTIES TIMEOUT 45)
    add_test(NAME trash_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/trash_runtime_test.py)
    set_tests_properties(trash_runtime PROPERTIES TIMEOUT 45)
    add_test(NAME application_media COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/media_runtime_test.py)
    set_tests_properties(application_media PROPERTIES TIMEOUT 45)
    add_test(NAME window_activation COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py $<TARGET_FILE:window_activation_test>)
    set_tests_properties(window_activation PROPERTIES TIMEOUT 45)
    add_test(NAME window_activation_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/window_activation_runtime_test.py)
    set_tests_properties(window_activation_runtime PROPERTIES TIMEOUT 45)
    add_test(NAME window_models COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py $<TARGET_FILE:window_models_test>)
    set_tests_properties(window_models PROPERTIES TIMEOUT 45)
    add_test(NAME running_state COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- $<TARGET_FILE:running_state_test>)
    add_test(NAME running_marker_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${DBUS_RUN_SESSION_EXECUTABLE} -- ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/running_marker_runtime_test.py)
    add_test(NAME window_dodge_runtime COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_SOURCE_DIR}/scripts-dev/run-isolated.py --
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts-dev/run-private-bus.py
        ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/window_dodge_runtime_test.py)
    set_tests_properties(window_dodge_runtime PROPERTIES TIMEOUT 45)
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
    set_tests_properties(qml_lint dock_components application_launch popup_runtime recent_documents places_runtime application_items settings_theme configuration_runtime running_state running_marker_runtime settings_reload window_capability project_foundation PROPERTIES TIMEOUT 45)
endif()

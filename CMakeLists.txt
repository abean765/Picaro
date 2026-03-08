cmake_minimum_required(VERSION 3.16)
project(Picaro VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Quick
    QuickControls2
    Sql
    Concurrent
    Multimedia
)

find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBHEIF REQUIRED libheif)
pkg_check_modules(EXIV2 REQUIRED exiv2)

qt_add_executable(picaro
    src/main.cpp
    src/PhotoDatabase.h
    src/PhotoDatabase.cpp
    src/PhotoModel.h
    src/PhotoModel.cpp
    src/PhotoImporter.h
    src/PhotoImporter.cpp
    src/ThumbnailProvider.h
    src/ThumbnailProvider.cpp
    src/HeicImageReader.h
    src/HeicImageReader.cpp
)

qt_add_qml_module(picaro
    URI Picaro
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/PhotoGridView.qml
        qml/ImportDialog.qml
)

target_include_directories(picaro PRIVATE
    ${LIBHEIF_INCLUDE_DIRS}
    ${EXIV2_INCLUDE_DIRS}
)

target_link_libraries(picaro PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Concurrent
    Qt6::Multimedia
    ${LIBHEIF_LIBRARIES}
    ${EXIV2_LIBRARIES}
)

target_compile_definitions(picaro PRIVATE
    QT_NO_CAST_FROM_ASCII
    QT_NO_CAST_TO_ASCII
)

install(TARGETS picaro DESTINATION bin)

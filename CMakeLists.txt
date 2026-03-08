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

# Optional dependencies: libheif and exiv2
# On Linux: found via pkg-config
# On Windows: set LIBHEIF_DIR / EXIV2_DIR or install via vcpkg
find_package(PkgConfig QUIET)

set(HAVE_LIBHEIF OFF)
set(HAVE_EXIV2 OFF)

if(PkgConfig_FOUND)
    pkg_check_modules(LIBHEIF QUIET libheif)
    pkg_check_modules(EXIV2 QUIET exiv2)
endif()

# Allow finding via CMake config mode (vcpkg, manual install)
if(NOT LIBHEIF_FOUND)
    find_package(libheif QUIET CONFIG)
    if(libheif_FOUND)
        set(LIBHEIF_FOUND TRUE)
        set(LIBHEIF_LIBRARIES heif)
    endif()
endif()

if(NOT EXIV2_FOUND)
    find_package(exiv2 QUIET CONFIG)
    if(exiv2_FOUND)
        set(EXIV2_FOUND TRUE)
        set(EXIV2_LIBRARIES Exiv2::exiv2lib)
    endif()
endif()

if(LIBHEIF_FOUND)
    set(HAVE_LIBHEIF ON)
    message(STATUS "libheif found - HEIC support enabled")
else()
    message(STATUS "libheif NOT found - HEIC support disabled")
endif()

if(EXIV2_FOUND)
    set(HAVE_EXIV2 ON)
    message(STATUS "exiv2 found - EXIF metadata support enabled")
else()
    message(STATUS "exiv2 NOT found - EXIF metadata support disabled (using file dates)")
endif()

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
)

if(HAVE_LIBHEIF)
    target_link_libraries(picaro PRIVATE ${LIBHEIF_LIBRARIES})
    target_compile_definitions(picaro PRIVATE HAVE_LIBHEIF)
endif()

if(HAVE_EXIV2)
    target_link_libraries(picaro PRIVATE ${EXIV2_LIBRARIES})
    target_compile_definitions(picaro PRIVATE HAVE_EXIV2)
endif()

target_compile_definitions(picaro PRIVATE
    QT_NO_CAST_FROM_ASCII
    QT_NO_CAST_TO_ASCII
)

install(TARGETS picaro DESTINATION bin)

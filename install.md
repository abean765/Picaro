# Picaro – Installation (Linux)

## Abhängigkeiten

### Erforderlich

- **CMake** ≥ 3.16
- **C++17-Compiler** (GCC ≥ 9, Clang ≥ 10)
- **Qt 6** mit folgenden Modulen:
  - Quick, QuickControls2, Sql, Concurrent, Multimedia

### Optional

- **libheif** – HEIC/HEIF-Unterstützung (iPhone-Fotos)
- **exiv2** – EXIF-Metadaten (Aufnahmedatum, Auflösung); ohne exiv2 wird das Dateidatum verwendet

## Pakete installieren

### Ubuntu / Debian

```bash
sudo apt install build-essential cmake \
  qt6-declarative-dev qt6-multimedia-dev libqt6sql6-sqlite \
  libgl-dev

# Optional
sudo apt install libheif-dev libexiv2-dev
```

### Fedora

```bash
sudo dnf install cmake gcc-c++ \
  qt6-qtdeclarative-devel qt6-qtmultimedia-devel qt6-qtbase-private-devel

# Optional
sudo dnf install libheif-devel exiv2-devel
```

### Arch Linux

```bash
sudo pacman -S cmake base-devel \
  qt6-declarative qt6-multimedia qt6-5compat

# Optional
sudo pacman -S libheif exiv2
```

## Bauen & Installieren

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

Das Binary wird nach `/usr/local/bin/picaro` installiert.

### Eigenes Prefix

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
cmake --build build -j$(nproc)
cmake --install build
```

## Hinweise

- Ohne **libheif** werden HEIC-Dateien nicht angezeigt. Die meisten iPhone-Fotos nutzen HEIC.
- Ohne **exiv2** wird statt dem Aufnahmedatum das Änderungsdatum der Datei verwendet.
- Qt6 Multimedia benötigt GStreamer-Plugins für die Video-Wiedergabe. Falls Videos nicht abgespielt werden:
  ```bash
  # Ubuntu/Debian
  sudo apt install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav

  # Fedora
  sudo dnf install gstreamer1-plugins-good gstreamer1-plugins-bad-free

  # Arch
  sudo pacman -S gst-plugins-good gst-plugins-bad gst-libav
  ```

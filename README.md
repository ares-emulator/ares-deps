# ares-deps

Cross-platform dependency build system for the [ares emulator](https://github.com/ares-emulator/ares).

Builds, packages and distributes precompiled libraries and resources needed by ares on all supported platforms.

## Dependencies

| Dependency | Version | Source | Strategy |
|---|---|---|---|
| [SDL3](https://github.com/libsdl-org/SDL) | 3.4.0 | `release-3.4.0` tag | Pre-built (Windows/macOS), compiled from source (Linux) |
| [librashader](https://github.com/SnowflakePowered/librashader) | 0.9.1 | `librashader-v0.9.1` tag | Compiled from source (all platforms, Rust stable) |
| [slang-shaders](https://github.com/libretro/slang-shaders) | 1.0 | commit `46dcd51d` | Cloned and cleaned (no compilation) |
| [MoltenVK](https://github.com/KhronosGroup/MoltenVK) | 1.4.1 | `v1.4.1` tag | Pre-built (macOS only) |

### Platform matrix

| Dependency | Linux x64 | Linux arm64 | macOS universal | Windows x64 | Windows arm64 |
|---|---|---|---|---|---|
| SDL3 | compiled | compiled | pre-built DMG | pre-built ZIP | pre-built ZIP |
| librashader | compiled | compiled | compiled (lipo universal) | compiled | compiled (cross aarch64) |
| slang-shaders | cloned | cloned | cloned | cloned | cloned |
| MoltenVK | - | - | pre-built tar | - | - |

## Build locally

```bash
./build_deps.sh <config>   # config: Debug | Release | RelWithDebInfo | MinSizeRel
```

The script auto-detects the platform (Linux/macOS/Windows) and loads the appropriate scripts from `deps.<os>/`. Output goes to the `ares-deps/` directory with a standard Unix prefix structure.

### Prerequisites

- **All platforms**: Rust stable toolchain
- **Linux**: CMake, build-essential, SDL3 build dependencies (X11, Wayland, audio, Vulkan dev packages)
- **macOS**: Xcode command line tools, Rust targets for `x86_64-apple-darwin` and `aarch64-apple-darwin`
- **Windows**: MSYS2 with clang64, Rust target `aarch64-pc-windows-msvc` (for arm64 builds)

## Architecture

### Build lifecycle

For each dependency, `build_deps.sh` calls these functions in order:

1. `<dep>_setup()` — Clone repo / download pre-built package
2. `<dep>_patch()` — Apply patches (currently none)
3. `<dep>_package_source()` — Archive source for debug symbols
4. `<dep>_build()` — Compile (or skip for pre-built packages)
5. `<dep>_install()` — Copy artifacts to `ares-deps/` prefix

Steps 1-4 run from the `build_temp/` directory. Step 5 runs from the repository root.

### Output structure

```
ares-deps/
├── lib/              # .so, .dylib, .dll, .lib, .pdb
├── include/          # Header files (SDL3/, librashader/)
├── share/            # Shader presets (slang-shaders)
└── licenses/         # License files per dependency
```

### Dependency scripts

Each dependency is defined in a platform-specific file:

```
deps.linux/          deps.macos/          deps.windows/
├── sdl              ├── sdl              ├── sdl
├── librashader      ├── librashader      ├── librashader
└── slang_shaders    ├── slang_shaders    └── slang_shaders
                     └── moltenvk
```

Each file declares metadata variables (`_name`, `_version`, `_url`) and implements the 5 lifecycle functions.

## CI/CD

### Build workflow

On every push and tag, GitHub Actions builds dependencies for all 5 platforms in parallel:

| Platform | Runner | Rust targets |
|---|---|---|
| `linux-x64` | `ubuntu-latest` | default |
| `linux-arm64` | `ubuntu-24.04-arm` | default |
| `macos-universal` | `macos-latest` | `x86_64-apple-darwin` + `aarch64-apple-darwin` |
| `windows-x64` | `windows-2025` (MSYS2) | default |
| `windows-arm64` | `windows-2025` (MSYS2) | `aarch64-pc-windows-msvc` |

### Release workflow

When a tag is pushed (e.g. `2025.02.06`), the `make-release` job runs after all builds succeed:

1. Downloads all 5 platform artifacts
2. Repackages them as `ares-deps-<platform>.tar.xz`
3. Generates SHA256 checksums
4. **Generates `deps.json`** — extracts versions and URLs from build scripts, computes hashes
5. Creates a GitHub release with all archives and `deps.json`

### deps.json

The `deps.json` file is automatically generated during releases and published as a release asset. It serves as a machine-readable manifest for consumers (e.g. [ares-snap](https://github.com/Le-Syl21/ares-snap)).

```json
{
  "version": "2025.02.06",
  "baseUrl": "https://github.com/Le-Syl21/ares-deps/releases/download",
  "dependencies": {
    "sdl":           { "version": "3.4.0", "tag": "release-3.4.0",         "url": "https://github.com/libsdl-org/SDL" },
    "librashader":   { "version": "0.9.1", "tag": "librashader-v0.9.1",   "url": "https://github.com/SnowflakePowered/librashader" },
    "slang-shaders": { "version": "1.0",   "commit": "46dcd51d...",        "url": "https://github.com/libretro/slang-shaders" },
    "moltenvk":      { "version": "1.4.1", "tag": "v1.4.1",               "url": "https://github.com/KhronosGroup/MoltenVK" }
  },
  "hashes": {
    "linux-x64":        "<sha256>",
    "linux-arm64":      "<sha256>",
    "macos-universal":  "<sha256>",
    "windows-x64":      "<sha256>",
    "windows-arm64":    "<sha256>"
  }
}
```

| Field | Description |
|---|---|
| `version` | Release tag (used in download URLs) |
| `baseUrl` | GitHub releases base URL |
| `dependencies.<dep>.version` | Upstream version string |
| `dependencies.<dep>.tag` | Git tag used for checkout/download |
| `dependencies.<dep>.commit` | Pinned commit hash (when no tag exists) |
| `dependencies.<dep>.url` | Upstream repository URL |
| `hashes.<platform>` | SHA256 of `ares-deps-<platform>.tar.xz` |

### Creating a release

```bash
git tag 2025.02.06 -m "Release description"
git push origin 2025.02.06
```

The CI builds all platforms, generates `deps.json`, and publishes the release automatically.

## Updating a dependency

1. Edit the version in the relevant `deps.<os>/<dep>` files (all platforms)
2. Commit, push, create a new tag
3. Update `deps.json` in consumer repos (e.g. ares-snap) with the new release version and hashes

## License

Dependencies are distributed under their respective licenses, included in `ares-deps/licenses/`.

# Universal Proxy Party

A cross-platform proxy GUI application built with Flutter, supporting multiple kernels: **sing-box**, **v2ray-core**, and **mihomo (clash)**.

## Features

- 🚀 **Multi-Kernel Support**: Unified interface for sing-box, v2ray, and mihomo
- 🎨 **Modern UI**: Clean, Material Design 3 interface with dark mode support
- 📊 **Real-time Statistics**: Monitor traffic, connections, and performance
- 🔧 **Kernel Adapter Pattern**: Extensible architecture for easy kernel integration
- 💻 **Cross-Platform**: Windows, macOS, and Linux support

## Architecture

```
lib/
├── core/
│   ├── adapters/          # Kernel adapter implementations
│   │   ├── kernel_adapter.dart    # Abstract interface
│   │   ├── singbox_adapter.dart   # sing-box implementation
│   │   ├── mihomo_adapter.dart    # mihomo/clash implementation
│   │   └── v2ray_adapter.dart     # v2ray implementation
│   ├── managers/          # Business logic managers
│   │   └── kernel_manager.dart    # Kernel lifecycle management
│   └── models/            # Data models
│       ├── kernel_config.dart     # Configuration structures
│       ├── kernel_stats.dart      # Statistics data
│       └── kernel_error.dart      # Error handling
├── ui/
│   ├── screens/           # App screens
│   └── widgets/           # Reusable UI components
└── utils/                 # Utilities and helpers
```

## Getting Started

### Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd universal-proxy-party
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

### Building for Production

```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

## Binary Management

Place kernel binaries in the `binaries/` directory:

```
binaries/
├── windows/
│   ├── sing-box.exe
│   ├── v2ray.exe
│   └── clash.exe
├── macos/
│   ├── sing-box
│   ├── v2ray
│   └── clash
└── linux/
    ├── sing-box
    ├── v2ray
    └── clash
```

## Development

### Project Structure

- **Kernel Adapters**: Implement the `KernelAdapter` interface to add support for new kernels
- **Models**: Define data structures using `json_serializable` for JSON parsing
- **State Management**: Uses Provider pattern for state management
- **Logging**: Integrated logger package for debugging

### Adding a New Kernel

1. Create a new adapter class extending `KernelAdapter`
2. Implement required methods: `start()`, `stop()`, `restart()`, `fetchStats()`, `healthCheck()`, `validateConfig()`
3. Register the adapter in `KernelManager.createAdapter()`

## Roadmap

- [ ] Complete API integration for all kernels
- [ ] System proxy configuration
- [ ] Profile management
- [ ] Rule-based routing
- [ ] Real-time traffic charts
- [ ] Auto-update for kernel binaries
- [ ] Tray icon support

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

# OpenClawWatcher

A native macOS menu bar app to monitor and manage [OpenClaw](https://openclaw.ai) gateway processes.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar Status** - Shows 🦞 (running) or 💀 (stopped)
- **Process Control** - Start, stop, and restart the OpenClaw gateway
- **Desktop Notifications** - Get notified when gateway status changes
- **Dashboard Access** - One-click access to OpenClaw Control UI with auto-authentication
- **Log Viewer** - Quick access to gateway logs
- **Launch at Login** - Optional auto-start with macOS

## Screenshots

```
🦞 ← Menu bar when running
💀 ← Menu bar when stopped
```

## Installation

### Build from Source

```bash
git clone https://github.com/yourusername/OpenClawWatcher.git
cd OpenClawWatcher
./build.sh
cp -r build/OpenClawWatcher.app /Applications/
```

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- [OpenClaw](https://openclaw.ai) installed

## Usage

1. Launch OpenClawWatcher from `/Applications`
2. Look for the 🦞 or 💀 icon in your menu bar
3. Click to access controls:
   - **Start Gateway** (`⌘S`)
   - **Stop Gateway** (`⌘X`)
   - **Restart Gateway** (`⌘R`)
   - **Open Dashboard** (`⌘D`)
   - **View Logs** (`⌘L`)
   - **Launch at Login** - Toggle auto-start
   - **Quit** (`⌘Q`)

## Configuration

OpenClawWatcher reads the OpenClaw configuration from `~/.openclaw/openclaw.json` to:
- Get the gateway authentication token for dashboard access
- Determine the gateway port (default: 18789)

## Security

- Runs with minimal permissions
- No network access except localhost for dashboard
- Reads only the OpenClaw config file (for auth token)
- Uses macOS native APIs for process management
- Ad-hoc code signed for local use

### Security Audit

See [SECURITY.md](SECURITY.md) for the full security audit.

## Building

```bash
# Make build script executable
chmod +x build.sh

# Build the app
./build.sh

# Output: build/OpenClawWatcher.app
```

## Contributing

Contributions welcome! Please read the security considerations before submitting PRs.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [OpenClaw](https://openclaw.ai) - The AI assistant platform this monitors
- Built with Swift and AppKit

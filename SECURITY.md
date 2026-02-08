# Security Audit Report

**Application:** OpenClawWatcher
**Version:** 1.0
**Audit Date:** February 2026
**Auditor:** Claude Code

## Summary

OpenClawWatcher is a macOS menu bar application that monitors and controls OpenClaw gateway processes. This audit reviewed the application for security vulnerabilities.

**Overall Risk Level:** LOW

## Findings

### Addressed Issues

| Issue | Severity | Status |
|-------|----------|--------|
| Shell command injection via Process | MEDIUM | FIXED |
| Symlink traversal on config file | LOW | FIXED |
| Loose file permissions warning | INFO | FIXED |
| Token length validation | LOW | FIXED |
| Debug logging in production | INFO | FIXED |
| Timer memory leak | LOW | FIXED |

### Details

#### 1. Shell Command Execution (FIXED)

**Before:** Used `/bin/zsh -c` for process control commands
**After:** Direct process execution with `executableURL` and explicit `arguments` array where possible

The `startGateway()` function still requires shell execution for `nohup` background process handling, but uses hardcoded arguments only.

#### 2. Symlink Traversal Protection (FIXED)

**Before:** Config file path was read without validating resolved path
**After:** Symlinks are resolved and validated to ensure the path stays within the user's home directory:

```swift
let resolvedPath = (configPath as NSString).resolvingSymlinksInPath
guard resolvedPath.hasPrefix(NSHomeDirectory()) else {
    debugLog("Security: Config path resolves outside home directory")
    return nil
}
```

#### 3. File Permission Checks (FIXED)

Added warning when config file has world-readable permissions:

```swift
if otherPerms != 0 {
    debugLog("Warning: Config file has loose permissions")
}
```

#### 4. Token Validation (FIXED)

Added basic token validation to prevent obviously malformed tokens:

```swift
guard token.count >= 10, token.count <= 1024 else {
    debugLog("Token has invalid length")
    return nil
}
```

#### 5. URL Token Handling (VERIFIED SAFE)

The dashboard URL uses a fragment (`#token=`) rather than a query parameter (`?token=`). URL fragments are:
- Not sent to the server in HTTP requests
- Not logged in server access logs
- Not visible in referrer headers

#### 6. Debug Logging (FIXED)

Debug output is now conditional and disabled in release builds:

```swift
#if DEBUG
func debugLog(_ message: String) {
    print("[ClawdMonitor] \(message)")
}
#else
func debugLog(_ message: String) {}
#endif
```

## Threat Model

### In Scope
- Local privilege escalation
- Information disclosure
- Command injection
- Path traversal

### Out of Scope
- Network attacks (app only connects to localhost)
- Physical access attacks
- OpenClaw gateway security (separate project)

## Permissions

The app requires minimal permissions:
- **Notifications:** User-granted for status change alerts
- **Network:** Localhost only (127.0.0.1:18789)
- **File System:** Read-only access to `~/.openclaw/openclaw.json`
- **Process Control:** Can start/stop `openclaw gateway` process

## Recommendations

1. **For Users:**
   - Keep `~/.openclaw/openclaw.json` permissions at 600 (owner read/write only)
   - Do not run the app as root

2. **For Development:**
   - Consider sandboxing in future versions
   - Add entitlements for App Store distribution if desired

## Verification

To verify the security of your installation:

```bash
# Check config file permissions (should be 600 or 644)
ls -la ~/.openclaw/openclaw.json

# Verify binary is signed
codesign -dv /Applications/OpenClawWatcher.app
```

## Reporting Issues

If you discover a security vulnerability, please open an issue on GitHub or contact the maintainer directly.

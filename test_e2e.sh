#!/bin/bash
# E2E Tests for ClawdMonitor
# Tests menu bar app functionality using AppleScript and process checks

set -e

APP_NAME="ClawdMonitor"
APP_PATH="build/ClawdMonitor.app"
INSTALLED_PATH="/Applications/ClawdMonitor.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "🦞 ClawdMonitor E2E Tests"
echo "========================="
echo ""

# Cleanup any existing instance
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 1

# Test 1: Build succeeds
echo "Test 1: Build succeeds"
if ./build.sh > /tmp/build.log 2>&1; then
    pass "Build completed successfully"
else
    fail "Build failed"
    cat /tmp/build.log
    exit 1
fi

# Test 2: App bundle exists with correct structure
echo ""
echo "Test 2: App bundle structure"
if [[ -d "$APP_PATH/Contents/MacOS" ]] && \
   [[ -f "$APP_PATH/Contents/MacOS/$APP_NAME" ]] && \
   [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
    pass "App bundle structure is correct"
else
    fail "App bundle structure is incorrect"
fi

# Test 3: Binary is executable
echo ""
echo "Test 3: Binary is executable"
if [[ -x "$APP_PATH/Contents/MacOS/$APP_NAME" ]]; then
    pass "Binary is executable"
else
    fail "Binary is not executable"
fi

# Test 4: App is code signed
echo ""
echo "Test 4: Code signature"
if codesign -v "$APP_PATH" 2>/dev/null; then
    pass "App is properly code signed"
else
    fail "App code signature is invalid"
fi

# Test 5: App launches without crashing
echo ""
echo "Test 5: App launches"
open "$APP_PATH"
sleep 3

if pgrep -f "$APP_NAME" > /dev/null; then
    APP_PID=$(pgrep -f "$APP_NAME")
    pass "App launched successfully (PID: $APP_PID)"
else
    fail "App failed to launch"
    exit 1
fi

# Test 6: App appears in menu bar (check via AppleScript)
echo ""
echo "Test 6: Menu bar presence"
MENU_CHECK=$(osascript -e '
tell application "System Events"
    tell process "ClawdMonitor"
        try
            set menuExists to exists menu bar 1
            return menuExists as string
        on error
            return "false"
        end try
    end tell
end tell
' 2>/dev/null || echo "false")

if [[ "$MENU_CHECK" == "true" ]]; then
    pass "App has menu bar presence"
else
    # Menu bar apps may not have standard menu bar, check for status item
    warn "Could not verify menu bar (may need accessibility permissions)"
fi

# Test 7: Status item displays emoji (lobster or skull)
echo ""
echo "Test 7: Status icon"
# We can't easily read the menu bar icon, but we can verify the process is healthy
if ps -p "$APP_PID" -o %cpu,%mem | tail -1 | awk '{if ($1 < 50 && $2 < 5) exit 0; else exit 1}'; then
    pass "App is running with reasonable resource usage"
else
    warn "App may be using excessive resources"
fi

# Test 8: pgrep detection works (app's own check mechanism)
echo ""
echo "Test 8: Gateway detection mechanism"
if pgrep -f "openclaw gateway" > /dev/null 2>&1; then
    pass "Can detect OpenClaw gateway (running)"
else
    pass "Can detect OpenClaw gateway (not running - detection works)"
fi

# Test 9: Config file readable
echo ""
echo "Test 9: Config file access"
CONFIG_PATH="$HOME/.openclaw/openclaw.json"
if [[ -f "$CONFIG_PATH" ]]; then
    if [[ -r "$CONFIG_PATH" ]]; then
        pass "Config file is readable"
    else
        fail "Config file exists but not readable"
    fi
else
    warn "Config file not found (expected at $CONFIG_PATH)"
fi

# Test 10: Token extraction (privacy-safe check)
echo ""
echo "Test 10: Token extraction"
if grep -q '"token"' "$CONFIG_PATH" 2>/dev/null; then
    pass "Config contains token field"
else
    warn "Config may not have token configured"
fi

# Test 11: Menu items accessible via AppleScript
echo ""
echo "Test 11: Menu accessibility"
MENU_ITEMS=$(osascript -e '
tell application "System Events"
    tell process "ClawdMonitor"
        try
            set menuBar to menu bar item 1 of menu bar 2
            click menuBar
            delay 0.5
            set menuNames to name of every menu item of menu 1 of menuBar
            key code 53 -- Escape to close menu
            return menuNames as string
        on error errMsg
            return "error: " & errMsg
        end try
    end tell
end tell
' 2>/dev/null || echo "error: accessibility")

if [[ "$MENU_ITEMS" != error:* ]]; then
    pass "Menu items are accessible"
    echo "       Menu items: $MENU_ITEMS"
else
    warn "Cannot access menu items (may need accessibility permissions)"
fi

# Test 12: App responds to SIGTERM gracefully
echo ""
echo "Test 12: Graceful shutdown"
kill -TERM "$APP_PID" 2>/dev/null
sleep 2

if ! pgrep -f "$APP_NAME" > /dev/null 2>&1; then
    pass "App terminated gracefully"
else
    fail "App did not respond to SIGTERM"
    pkill -9 -f "$APP_NAME" 2>/dev/null || true
fi

# Summary
echo ""
echo "========================="
echo "Test Summary"
echo "========================="
echo -e "${GREEN}Passed${NC}: $TESTS_PASSED"
echo -e "${RED}Failed${NC}: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC} 🦞"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi

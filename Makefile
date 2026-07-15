# SkillCast — build/run/test helpers
# Requires: Xcode Command Line Tools (swift build/run); full Xcode for `test` (XCTest)

.PHONY: build run test app icon install clean

# Build the release binary via SwiftPM.
build:
	swift build -c release

# Run the app directly from source (menu-bar app).
run:
	swift run

# Run the unit tests.
test:
	swift test

# Bundle build/SkillCast.app (no install).
app:
	./scripts/make_app.sh

# Regenerate Resources/AppIcon.icns.
icon:
	./scripts/build_icon.sh

# Build, install to /Applications, reset TCC and (re)launch.
install:
	./scripts/make_app.sh --install

# Remove SwiftPM and app-bundle build artifacts.
clean:
	swift package clean
	rm -rf .build build

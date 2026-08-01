# Personal build shortcuts for the fork (see the `fdroid` flavor in android/app/build.gradle).
# The fdroid flavor carries our own applicationId, so these builds never clash with
# an upstream Organic Maps install.

app_id := "lol.fyhn.organicmaps"
# Launcher component. The Java package stays app.organicmaps regardless of applicationId.
launcher := app_id + "/app.organicmaps.DownloadResourcesActivity"
apk_dir := "android/app/build/outputs/apk/fdroid/release"

set default-list := true

# Build the release APK for arm64
build:
    # Don't add -Ppch: it breaks the NDK CMake configure.
    cd android && ./gradlew assembleFdroidRelease -Parm64

# Build and install onto the connected device
install: build
    adb install -r "$(ls -t {{apk_dir}}/*.apk | head -1)"

# Build, install and run
run: install
    adb shell am start -n {{launcher}}

# Show logs
log:
    adb logcat --pid="$(adb shell pidof {{app_id}})"

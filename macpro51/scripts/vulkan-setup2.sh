set -u
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME" || exit 1
say "=== unzip ==="
rm -rf vulkansdk-unzip; mkdir vulkansdk-unzip
unzip -q vulkan-sdk.dmg -d vulkansdk-unzip 2>&1 | tail -3
ls vulkansdk-unzip | head
APP=$(find vulkansdk-unzip -maxdepth 1 -name "*.app" | head -1)
say "app: $APP"
say "=== key pieces inside ==="
find "$APP" -maxdepth 5 \( -name glslc -o -name "libMoltenVK*" -o -name "vulkan_core.h" -o -name "*.icd.json" -o -name "setup-env.sh" \) 2>/dev/null | head -15
say "=== top-level tree ==="
find "$APP" -maxdepth 3 -type d 2>/dev/null | head -20
say "DONE-VULKAN-SETUP2"

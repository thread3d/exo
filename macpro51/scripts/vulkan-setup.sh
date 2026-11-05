set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== fetch LunarG macOS Vulkan SDK (has glslc + MoltenVK + headers) ==="
cd "$HOME" || exit 1
curl -sS -L --max-time 1200 -o vulkan-sdk.dmg "https://sdk.lunarg.com/sdk/download/latest/mac/vulkan-sdk.dmg" -w 'http %{http_code} size %{size_download}\n'
ls -lh vulkan-sdk.dmg
say "=== mount it ==="
MP=$(hdiutil attach -nobrowse -readonly vulkan-sdk.dmg 2>/dev/null | tail -1 | awk -F'\t' '{print $NF}')
echo "mountpoint: $MP"
ls "$MP" 2>/dev/null | head
say "=== look for glslc / MoltenVK / headers inside ==="
find "$MP" -maxdepth 4 \( -name glslc -o -name "libMoltenVK*" -o -name "vulkan_core.h" -o -name "*.icd.json" \) 2>/dev/null | head -12
say "=== also check for a plain SDK tree ==="
find "$MP" -maxdepth 3 -type d 2>/dev/null | head -15
echo "MP=$MP" > ~/vulkan-mp.txt
say "DONE-VULKAN-SETUP"

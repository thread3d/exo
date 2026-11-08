# EXO Platform support (partial roadmap)

## Tier 1 support - tested and maintained

Apple Silicon MacOS
- Mac Studio: M3 Ultra
- Mac Mini: M4 Pro
- Macbook Pro: M5, M4 Max

## Tier 2 support - checked occasionally, should run without crashing


## Tier 3 support - minimal support and testing, but no theoretical reason it shouldnt work

Linux CPU Support (x86_64)
- Mac Pro 7,1 running Fedora 44, via MLX's CPU backend (`exo[mlx-cpu]`): one node serves the
  dashboard, the API and real completions. Slow - MLX's x86 CPU backend does not use BLAS for
  fp16, and emulates fp16 arithmetic - see `macpro71fedora/STATUS.md` for the measurements.

# Planned

## Tier 1

Linux CUDA Support
- Nvidia DGX Spark

Linux CPU Support

## Tier 2

Linux Vulkan Support -- depends heavily on ecosystem
- Framework Desktop

Linux CUDA Support -- depends heavily on ecosystem
- Framework Desktop

## Longer term!

Windows CUDA Support

Windows CPU Support


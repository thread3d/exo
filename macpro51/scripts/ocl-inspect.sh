set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
echo "=== ggml-opencl files ==="
ls ggml/src/ggml-opencl | head -20
echo "=== CMake options for OpenCL ==="
grep -rn "GGML_OPENCL" CMakeLists.txt ggml/CMakeLists.txt ggml/src/CMakeLists.txt ggml/src/ggml-opencl/CMakeLists.txt 2>/dev/null | head -20
echo "=== fp16 / extension requirements in the backend ==="
grep -rn -i -E "cl_khr_fp16|CL_DEVICE_EXTENSIONS|fp16" ggml/src/ggml-opencl/ggml-opencl.cpp | head -20
echo "=== hard version / platform checks ==="
grep -rn -i -E "opencl 2|CL_DEVICE_VERSION|CL_DEVICE_NAME|not support|unsupported|GGML_ABORT" ggml/src/ggml-opencl/ggml-opencl.cpp | head -25
echo "=== docs ==="
ls docs | grep -i opencl; find . -maxdepth 2 -iname "*opencl*" -not -path "./ggml/*" | head

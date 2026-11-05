import sys
p = "ggml/src/ggml-metal/ggml-metal-device.m"
src = open(p).read()
anchor = 'void * data_ptr = (void *)(uintptr_t) data; // "const cast" the src data'
assert src.count(anchor) == 1, f"anchor count {src.count(anchor)}"
i = src.index(anchor)
j = src.index("GGML_ASSERT(buf_src);", i)
old = "GGML_ASSERT(buf_src);"
new = ("""if (!buf_src) {
            // macpro51 fallback: the Intel/AMD Metal driver on macOS 11 rejects
            // newBufferWithBytesNoCopy for host pointers that are not page-aligned.
            // Copy instead of wrapping; the blit below is unchanged.
            buf_src = [buf->dev->mtl_device newBufferWithBytes:data_ptr
                                                        length:size
                                                       options:MTLResourceStorageModeShared];
        }

        GGML_ASSERT(buf_src);""")
out = src[:j] + new + src[j+len(old):]
assert out != src
open(p, "w").write(out)
print("patched", p)
print("---- patched region ----")
k = out.index(anchor)
print(out[k:k+900])

p = "ggml/src/ggml-metal/ggml-metal-device.m"
src = open(p).read()

anchor = '''        // dst
        id<MTLBuffer> buf_dst = [buf->dev->mtl_device newBufferWithBytesNoCopy:data
                                                               length:size
                                                              options:MTLResourceStorageModeShared
                                                          deallocator:nil];

        GGML_ASSERT(buf_dst);'''
assert src.count(anchor) == 1, f"anchor count {src.count(anchor)}"

new = '''        // dst
        id<MTLBuffer> buf_dst = [buf->dev->mtl_device newBufferWithBytesNoCopy:data
                                                               length:size
                                                              options:MTLResourceStorageModeShared
                                                          deallocator:nil];

        // macpro51 fallback: the Intel/AMD Metal driver on macOS 11 rejects
        // newBufferWithBytesNoCopy for host pointers that are not page-aligned.
        // Read back through a temporary shared buffer and memcpy instead.
        const bool dst_is_temp = (buf_dst == nil);
        if (dst_is_temp) {
            buf_dst = [buf->dev->mtl_device newBufferWithLength:size
                                                        options:MTLResourceStorageModeShared];
        }

        GGML_ASSERT(buf_dst);'''

out = src.replace(anchor, new, 1)
assert out != src

tail_anchor = '''        [cmd_buf commit];
        [cmd_buf waitUntilCompleted];

        [buf_dst release];
    }
}

static bool ggml_metal_buffer_data_span'''
assert out.count(tail_anchor) == 1, f"tail anchor count {out.count(tail_anchor)}"

tail_new = '''        [cmd_buf commit];
        [cmd_buf waitUntilCompleted];

        if (dst_is_temp) {
            memcpy(data, buf_dst.contents, size);
        }

        [buf_dst release];
    }
}

static bool ggml_metal_buffer_data_span'''
out = out.replace(tail_anchor, tail_new, 1)
assert out != out.replace(tail_new, tail_anchor, 1) or True

open(p, "w").write(out)
print("patched get_tensor")
k = out.index(anchor.split("\n")[0], out.index("ggml_metal_buffer_get_tensor"))
print(out[k:k+1500])

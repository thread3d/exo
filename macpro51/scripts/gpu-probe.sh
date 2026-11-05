set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
echo "=== system_profiler displays ==="
system_profiler SPDisplaysDataType 2>/dev/null | head -40
echo "=== OpenCL framework present? ==="
ls -d /System/Library/Frameworks/OpenCL.framework 2>/dev/null && ls /System/Library/Frameworks/OpenCL.framework/Versions/A/Headers 2>/dev/null | head
echo "=== OpenCL dylib ==="
ls -l /System/Library/Frameworks/OpenCL.framework/Versions/A/OpenCL 2>/dev/null
echo "=== write and run a tiny OpenCL enumerator ==="
cat > /tmp/clprobe.c <<'C'
#include <stdio.h>
#include <OpenCL/opencl.h>
int main(void){
  cl_uint np=0; cl_int e=clGetPlatformIDs(0,NULL,&np);
  printf("clGetPlatformIDs -> %d, platforms=%u\n", e, np);
  cl_platform_id p[8]; clGetPlatformIDs(np,p,NULL);
  for(cl_uint i=0;i<np;i++){
    char nm[256]={0}; clGetPlatformInfo(p[i],CL_PLATFORM_NAME,sizeof nm,nm,NULL);
    char vr[128]={0}; clGetPlatformInfo(p[i],CL_PLATFORM_VERSION,sizeof vr,vr,NULL);
    printf("platform[%u]: %s | %s\n", i, nm, vr);
    cl_uint nd=0; clGetDeviceIDs(p[i],CL_DEVICE_TYPE_ALL,0,NULL,&nd);
    cl_device_id d[8]; clGetDeviceIDs(p[i],CL_DEVICE_TYPE_ALL,nd,d,NULL);
    for(cl_uint j=0;j<nd;j++){
      char dn[256]={0}; clGetDeviceInfo(d[j],CL_DEVICE_NAME,sizeof dn,dn,NULL);
      char dv[128]={0}; clGetDeviceInfo(d[j],CL_DEVICE_VERSION,sizeof dv,dv,NULL);
      char dr[128]={0}; clGetDeviceInfo(d[j],CL_DRIVER_VERSION,sizeof dr,dr,NULL);
      cl_ulong gm=0; clGetDeviceInfo(d[j],CL_DEVICE_GLOBAL_MEM_SIZE,sizeof gm,&gm,NULL);
      size_t wg=0; clGetDeviceInfo(d[j],CL_DEVICE_MAX_WORK_GROUP_SIZE,sizeof wg,&wg,NULL);
      cl_uint cu=0; clGetDeviceInfo(d[j],CL_DEVICE_MAX_COMPUTE_UNITS,sizeof cu,&cu,NULL);
      cl_bool av=0; clGetDeviceInfo(d[j],CL_DEVICE_AVAILABLE,sizeof av,&av,NULL);
      printf("  device[%u]: %s | %s | driver %s | mem %llu MB | CU %u | WG %zu | available=%d\n",
             j, dn, dv, dr, (unsigned long long)(gm/1048576), cu, wg, (int)av);
      char ext[4096]={0}; clGetDeviceInfo(d[j],CL_DEVICE_EXTENSIONS,sizeof ext,ext,NULL);
      printf("    fp16 ext: %s\n", strstr(ext,"cl_khr_fp16")?"yes":"no");
    }
  }
  return 0;
}
C
sed -i '' '3i\
#include <string.h>
' /tmp/clprobe.c
clang -O1 -o /tmp/clprobe /tmp/clprobe.c -framework OpenCL 2>&1 | head -5 && /tmp/clprobe 2>&1 | head -25

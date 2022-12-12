# RISC-V System On Chip with OLIMP extension

The demo **RISC-V SoC** on [IceBreaker](https://github.com/icebreaker-fpga/icebreaker) implements:

   * **CPU** @ **20Mhz** **rv32im** using [PicoRV32](https://github.com/cliffordwolf/picorv32) with ISA extensions
   * **4MByte ROM** as fast Quad (x4) DDR (+QPI) continuous memory mapped @ **40Mhz** I/O clock
   * **128kByte RAM** main memory organized as **64bit** wide (4 x 32kByte SRAM)
   * **128bit wide** BRAM memory for coefficients (N x 8 x 128Byte BRAM)
   * RISC-V **ISA extended** with OLIMP **VEC-8U8-16I8-2S32** running @ **40Mhz** DSP clock

*Note*: OLIMP VEC-8U8-16I8-2S32 is the largest possible vector block that fits ICE40 up5k.
  
-------------------------------------------------------------------------------------

## The OLIMP **VEC-8U8-16I8-2S32** block:

```
IN Vectors:
    8 x uint8 ( 64 bit)
   16 x  int8 (128 bit)
   ---------------------
OUT Lanes:
   2 x int32  (2 x 32 bit)
```
![8U8-16I8-2S32](/docs/imgs/OLIMP-VEC-1x8U8-2x8I8-2S32.png)


The OLIMP block extends the **rv32im** ISA via [PCPI](https://github.com/cliffordwolf/picorv32#pico-co-processor-interface-pcpi) interface.

The **VEC-8U8-16I8-2S32** block executes in **2 x CPU clock** cycles but picorv32 PCPI completes in **6 x CPU clock** cycles.

-------------------------------------------------------------------------------------

## TVM magic tensorization using OLIMP's MACC

Example of generated TIR representation for a MATMUL [64x64]*[64x64] inside TVM:

```
primfn(X_1: handle, W_1: handle, F.wmma.accumulator_1: handle) -> ()
  attr = {"global_symbol": "main", "tir.noalias": True}
  buffers = {F.wmma.accumulator: Buffer(F.wmma.accumulator_2: Pointer(int32), int32, [64, 64], []),
             W: Buffer(W_2: Pointer(int8), int8, [64, 64], []),
             X: Buffer(X_2: Pointer(uint8), uint8, [64, 64], [])}
  buffer_map = {X_1: X, W_1: W, F.wmma.accumulator_1: F.wmma.accumulator} {
  attr [F: Pointer(int32)] "storage_scope" = "global";
  allocate(F, int32, [4096]);
  for (i: int32, 0, 64) {
    for (j.outer: int32, 0, 32) {
      @tir.call_extern("O_VEC_MACZ",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, (i*64), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, (j.outer*128), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_MACC",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, ((i*64) + 8), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, ((j.outer*128) + 8), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_MACC",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, ((i*64) + 16), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, ((j.outer*128) + 16), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_MACC",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, ((i*64) + 24), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, ((j.outer*128) + 24), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_MACC",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, ((i*64) + 32), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, ((j.outer*128) + 32), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_MACC",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, ((i*64) + 40), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, ((j.outer*128) + 40), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_MACC",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, ((i*64) + 48), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, ((j.outer*128) + 48), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_MACC",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=uint8), X_2, ((i*64) + 56), 8, 1, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int8), W_2, ((j.outer*128) + 56), 128, 1, dtype=handle), 64, dtype=int32)
      @tir.call_extern("O_VEC_STOR",
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F, ((i*64) + (j.outer*2)), 2, 2, dtype=handle),
        @tir.tvm_access_ptr(@tir.type_annotation(, dtype=int32), F.wmma.accumulator_2, ((i*64) + (j.outer*2)), 2, 1, dtype=handle), dtype=int32)
    }
  }
}
```

 [TVM](https://github.com/apache/tvm) leverage **complete** end-to-end code generation to **C language** using OLIMP hardware scheduling:

   * All **dense** operations will benefit **@tir.call_extern("O_VEC_")** the OLIMP hardware block.
   * Further **conv2d** schedules translates to many **dense** schedules
   * Any **other** operators not covered by OLIMP hardware will be covered by the soft RV32IM (slower)
   * TVM schedulers also **guarantee** continuous & aligned access to the vector segments in memory
   * TVM schedulers **handle memory** prefetching (DMA) or constrained access from slow memory regions.

### Example of generated C code

```
// tvm target: c -keys=cpu -link-params=0
#define TVM_EXPORTS
#include "tvm/runtime/c_runtime_api.h"
#include "tvm/runtime/c_backend_api.h"
#include <math.h>
#ifdef __cplusplus
extern "C"
#endif
TVM_DLL int32_t intrinsic(void* args, void* arg_type_ids, int32_t num_args, void* out_ret_value, void* out_ret_tcode, void* resource_handle) {
  void* arg0 = (((TVMValue*)args)[0].v_handle);
  int32_t arg0_code = ((int32_t*)arg_type_ids)[(0)];
  void* arg1 = (((TVMValue*)args)[1].v_handle);
  int32_t arg1_code = ((int32_t*)arg_type_ids)[(1)];
  void* arg2 = (((TVMValue*)args)[2].v_handle);
  int32_t arg2_code = ((int32_t*)arg_type_ids)[(2)];
  void* X = (((DLTensor*)arg0)[0].data);
  void* arg0_shape = (((DLTensor*)arg0)[0].shape);
  void* arg0_strides = (((DLTensor*)arg0)[0].strides);
  int32_t dev_id = (((DLTensor*)arg0)[0].device.device_id);
  void* W = (((DLTensor*)arg1)[0].data);
  void* arg1_shape = (((DLTensor*)arg1)[0].shape);
  void* arg1_strides = (((DLTensor*)arg1)[0].strides);
  void* F_wmma_accumulator = (((DLTensor*)arg2)[0].data);
  void* arg2_shape = (((DLTensor*)arg2)[0].shape);
  void* arg2_strides = (((DLTensor*)arg2)[0].strides);
  if (!(arg0_strides == NULL)) {
  }
  if (!(arg1_strides == NULL)) {
  }
  if (!(arg2_strides == NULL)) {
  }
  void* F = TVMBackendAllocWorkspace(1, dev_id, (uint64_t)16384, 0, 32);
  if (F == NULL) {
    return -1;
  }
  for (int32_t i = 0; i < 64; ++i) {
    for (int32_t j_outer = 0; j_outer < 32; ++j_outer) {
      (void)O_VEC_MACZ(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + ((i * 64))), ((int8_t *)W + ((j_outer * 128))), 64);
      (void)O_VEC_MACC(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + (((i * 64) + 8))), ((int8_t *)W + (((j_outer * 128) + 8))), 64);
      (void)O_VEC_MACC(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + (((i * 64) + 16))), ((int8_t *)W + (((j_outer * 128) + 16))), 64);
      (void)O_VEC_MACC(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + (((i * 64) + 24))), ((int8_t *)W + (((j_outer * 128) + 24))), 64);
      (void)O_VEC_MACC(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + (((i * 64) + 32))), ((int8_t *)W + (((j_outer * 128) + 32))), 64);
      (void)O_VEC_MACC(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + (((i * 64) + 40))), ((int8_t *)W + (((j_outer * 128) + 40))), 64);
      (void)O_VEC_MACC(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + (((i * 64) + 48))), ((int8_t *)W + (((j_outer * 128) + 48))), 64);
      (void)O_VEC_MACC(((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))), ((uint8_t *)X + (((i * 64) + 56))), ((int8_t *)W + (((j_outer * 128) + 56))), 64);
      (void)O_VEC_STOR(((int32_t *)F + (((i * 64) + (j_outer * 2)))), ((int32_t *)F_wmma_accumulator + (((i * 64) + (j_outer * 2)))));
    }
  }
  if (TVMBackendFreeWorkspace(1, dev_id, F) != 0) {
    return -1;
  }
  return 0;
```

*Note*: [MACC_olimp()](/demo/icebreaker/src/firmware.c#L340) are wrapped **__asm__( ".word 0xRV32custom")** RV32 ISA extension for OLIMP hardware block.
 
-------------------------------------------------------------------------------------

## Synthesis on ICE40 UP5K (IceBreaker)

ICE40 UP5K summary (01-Jul-2021):
```
    ICESTORM_LC:  4394/ 5280    83%
    ICESTORM_RAM:   12/   30    40%
    ICESTORM_DSP:    8/    8   100%
    ICESTORM_SPRAM:  4/    4   100%
```

Clocking:
```
Info: Max frequency for clock 'clk_spi': 26.12 MHz (PASS at 25.00 MHz)
Info: Max frequency for clock 'clk_cpu': 24.72 MHz (PASS at 20.00 MHz)
```
*Note*: clk_spi (also drive ICE40_DSP) in fact closes > 40Mhz.

-------------------------------------------------------------------------------------


## ChangeLog
   * *01-Jun-2021* early demo experiments

## ToDo (WiP)
   * finish access to final accumulated lanes in RTL
   * add RTL for memapping small camera & microphone
   * publish TVM code parts to support: dense, conv2d
   * TVM tutorial on end-to-end nnet importing from tflow, pytorch, onnx
 

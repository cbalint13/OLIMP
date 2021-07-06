#!/usr/bin/python3

"""
  OLIMP VEC schedule validation script.
"""

##
## License: GPLv3
## https://www.gnu.org/licenses/gpl-3.0.en.html
##
## Copyright 2021
##       Cristian Balint < cristian dot balint at gmail dot com >
##

import sys
import tvm
import random
import string

import tvm.testing
from tvm import te

import numpy as np


debug = False

# init with OLIMP 8U8-16I8-2S32 example
INT8_MACS   = 8 # int8 elements per int32 accumulator
INT32_LANES = 2 # int32 accumulator lanes (ACC0 & ACC1)

def OLIMP_VEC_MAC_impl():
    cc_code = f"""
        #include <stdint.h>
        #ifdef __cplusplus
        extern "C"
        #endif
        int32_t O_VEC_MACC(int32_t *output,
                             const uint8_t *data,
                             const int8_t *kernel,
                             const int32_t stride) {{
          for (int i = 0; i < {INT32_LANES}; ++i) {{
            for (int j = 0; j < {INT8_MACS}; ++j) {{
              output[i] += data[j] * kernel[i * stride + j];
            }}
          }}
          return 0;
        }}
        #ifdef __cplusplus
        extern "C"
        #endif
        int32_t O_VEC_MACZ(int32_t *output,
                             const uint8_t *data,
                             const int8_t *kernel,
                             const int32_t stride) {{
          for (int i = 0; i < {INT32_LANES}; ++i) {{
            output[i] = 0;
            for (int j = 0; j < {INT8_MACS}; ++j) {{
              output[i] += data[j] * kernel[i * stride + j];
            }}
          }}
          return 0;
        }}
        #ifdef __cplusplus
        extern "C"
        #endif
        int32_t O_VEC_STOR(int32_t *output,
                           const int32_t *acc) {{
          for (int i = 0; i < {INT32_LANES}; ++i) {{
            output[i] = acc[i];
          }}
          return 0;
        }}
    """

    from tvm.contrib import utils, clang
    temp = utils.tempdir()
    ll_path = temp.relpath("temp.ll")
    # llvm ir from c source code
    ll_code = clang.create_llvm(cc_code, output=ll_path)
    return ll_code

def OLIMP_VEC_MAC():
    """
    Int8 dot product by every INT8_MACS elements using OLIMP VEC
    instructions. This function takes two arrays of uint8 and int8
    datatype -- data[INT8_MACS] and coef[INT32_LANES][INT8_MACS] --
    and computes a dot product of data[INT8_MACS] with every INT8_MACS
    elements of coef[INT8_MACS], resulting acc[INT32_LANES] accumulators
    of int32 datatype.
    The pseudo code is as follows.
    .. code-block:: c
        void O_VEC_MAC{C,Z}(uint8 data[INT8_MACS],
                            int8 coef[INT32_LANES][INT8_MACS],
                            int32 acc[INT32_LANES]){
            for (int i = 0; i < INT32_LANES; i++){
                acc[i] = 0; // <- case of MACZ
                for (int k = 0; k < INT8_MACS; k++){
                    acc[i] += data[k] * coef[i][k]
                }
            }
        }

    Physically, the coef arrays are accessed via [INT32_LANES] by [INT8_MACS]
    memory order as the innermost region.

    This function returns a TensorIntrin that can be used to tensorize a schedule.

    Returns
    -------
    intrin : TensorIntrin
        The OLIMP MAC{C,Z} int8 TensorIntrin that can be used in tensorizing schedule
    """

    data = te.placeholder((INT8_MACS,), dtype='uint8', name='data')
    coef = te.placeholder((INT32_LANES, INT8_MACS), dtype='int8', name='coef')

    k = te.reduce_axis((0, INT8_MACS), name='k')
    C = te.compute((INT32_LANES,), lambda i:
                    te.sum( (data[   k] *
                             coef[i, k]).astype("int32"),
                           axis=k),
                    name="Co")

    Aa = tvm.tir.decl_buffer(data.shape, data.dtype, name="data_buffer",
                             scope="global",
                             offset_factor=1, strides=[1])
    Bb = tvm.tir.decl_buffer(coef.shape, coef.dtype, name="coef_buffer",
                             scope="global",
                             offset_factor=1, strides=[te.var("ldw"), 1])
    Co = tvm.tir.decl_buffer(C.shape, C.dtype, name="Co",
                             scope="global",
                             offset_factor=1, strides=[1])

    def intrin_func(ins, outs):
        Aa, Bb = ins
        Co = outs[0]
        def _body():
            ib = tvm.tir.ir_builder.create()
            o_vec_macz = tvm.tir.call_extern(
                                    "int32",
                                    f"O_VEC_MACZ",
                                    Co.access_ptr("w"),
                                    Aa.access_ptr("r"),
                                    Bb.access_ptr("r"),
                                    Bb.strides[0])
            ib.emit(o_vec_macz)
            return ib.get()
        def _reduce_reset():
            return None
        def _reduce_update():
            ib = tvm.tir.ir_builder.create()
            o_vec_macc = tvm.tir.call_extern(
                                    "int32",
                                    f"O_VEC_MACC",
                                    Co.access_ptr("w"),
                                    Aa.access_ptr("r"),
                                    Bb.access_ptr("r"),
                                    Bb.strides[0])
            ib.emit(o_vec_macc)
            return ib.get()
        return _body(), _reduce_reset(), _reduce_update()

    buffer_params = {"offset_factor" : 1}
    intrin_decl = te.decl_tensor_intrin(
        C.op, intrin_func, binds={data: Aa, coef: Bb, C: Co},
        default_buffer_params=buffer_params)
    return intrin_decl

def OLIMP_VEC_STR():
    """
    Copy every -- acc[INT32_LANES] -- accumulator elements to the main memory
    as reduction results of computation. The acc[INT32_LANES] registers
    are not visibile otherwise to the main system.

    This function returns a TensorIntrin that can be used to tensorize a schedule.

    Returns
    -------
    intrin : TensorIntrin
        The OLIMP STOR int32 TensorIntrin that can be used in tensorizing schedule
    """
    data = te.placeholder((INT32_LANES,), name="A", dtype="int32")

    C = te.compute((INT32_LANES,), lambda i: data[i], name="Cf")

    Aa = tvm.tir.decl_buffer(data.shape, data.dtype, name="Aa",
                             scope="global",
                             offset_factor=1)

    Co = tvm.tir.decl_buffer(C.shape, C.dtype, name="Cf",
                             scope="global",
                             offset_factor=1)

    def intrin_func(ins, outs):
        ib = tvm.tir.ir_builder.create()
        Aa = ins[0]
        Co = outs[0]
        o_vec_stor = tvm.tir.call_extern(
                                "int32",
                                f"O_VEC_STOR",
                                Co.access_ptr("w"),
                                Aa.access_ptr("r"))
        ib.emit(o_vec_stor)
        return ib.get()

    return te.decl_tensor_intrin(C.op, intrin_func, binds={data: Aa, C: Co})

##
##  C(m, n) = X(m, k) * W(n, k)
##  X is data
##  W is coef
##

# dummy arbitrary data matrix
M = 64 #64
N = 64 #64 # must be multiple of INT32_LANES
K = 64 #64 # must be multiple of INT8_MACS (the common axis)


def compute(target="llvm"):

    device = tvm.cpu(0)

    # inputs
    X = te.placeholder((M, K), name='X', dtype="uint8")
    W = te.placeholder((N, K), name='W', dtype="int8")

    ##
    ## weights ordering for vector computation
    ##

    # WEIGHT [N,          K                          ] ->
    # WEIGHT [N/I32LANES, K/I8MACS, I32_LANES, I8MACS]
    wshape = (N // INT32_LANES, K // INT8_MACS, INT32_LANES, INT8_MACS)
    coefW = te.compute(
        wshape,
        lambda r_idx, s_idx, l_idx, t_idx:
            W[r_idx * INT32_LANES + l_idx][s_idx * INT8_MACS + t_idx],
        name="Wcoef")

    ##
    ## matmul vector computation
    ##

    idxd = tvm.tir.indexdiv
    idxm = tvm.tir.indexmod
    ak = te.reduce_axis((0, K), name='k')
    C = te.compute((M, N), lambda i, j:
        te.sum(  (X[i, ak] *
                 coefW[idxd(j, INT32_LANES),
                        idxd(ak, INT8_MACS),
                        idxm(j, INT32_LANES),
                        idxm(ak, INT8_MACS)]).astype("int32")
              , axis=ak),
        name="F")

    ##
    ## matmul vector scheduling
    ##

    # create schedule
    s = te.create_schedule(C.op)

    # reorganize coef inline
    s[coefW].compute_inline()

    # schedule write cache
    CF = s.cache_write(C, "wmma.accumulator")

    # schedule flush write
    b_x, b_y = s[C].op.axis
    b_yo, b_yi = s[C].split(b_y, factor=INT32_LANES)

    # schedule compute
    a_x, a_y = s[CF].op.axis
    a_k,     = s[CF].op.reduce_axis
    a_yo, a_yi = s[CF].split(a_y, factor=INT32_LANES)
    a_ko, a_ki = s[CF].split(a_k, factor=INT8_MACS)
    # (lanes, macs) as inner most
    s[CF].reorder(a_yo, a_x, a_ko, a_yi, a_ki)
    # fuse all outer
    fuse = s[CF].fuse(a_yo, a_x)
    # flush accumulators to end
    s[CF].compute_at(s[C], b_yo)

    # unroll
    s[CF].unroll(a_ko)
    # tensorize vectors
    s[CF].tensorize(a_yi, OLIMP_VEC_MAC())
    # tensorize accumulators
    s[C].tensorize(b_yi, OLIMP_VEC_STR())


    ##
    ## graph and code generation
    ##

    # print lowered TIR computation graph
    print(tvm.lower(s, [X, W, CF], simple_mode=True))

    if (debug):
      # visual graph debug
      from tvm.contrib import tedd
      tedd.viz_dataflow_graph(s, dot_file_path = 'tvm-dfg.dot')
      tedd.viz_schedule_tree(s, dot_file_path = 'tvm-scheduletree.dot')
      t_s = s.normalize()
      tedd.viz_schedule_tree(t_s, dot_file_path = 'tvm-scheduletree_norm.dot')
      tedd.viz_itervar_relationship_graph(t_s, dot_file_path = 'tvm-itervar.dot')

    # imprint vector machine function calls
    s[CF].pragma(fuse, "import_llvm", OLIMP_VEC_MAC_impl())

    # compile whole computation graph
    t_func = tvm.build(s, [X, W, CF], target="llvm", name="intrinsic")

    if (debug):
      print(t_func.get_source())

    ##
    ## evaluate
    ##

    t_evaluator = t_func.time_evaluator(t_func.entry_name, device, number=0)

    # generate plain data
    a_ = np.random.uniform(1, 10, size=(M, K)).astype("uint8")
    b_ = np.random.uniform(1, 10, size=(N, K)).astype("int8")

    print("A shape =", a_.shape)
    print("B shape =", b_.shape)

    x = tvm.nd.array(a_, device)
    w = tvm.nd.array(b_, device)
    y = tvm.nd.array(np.zeros((M, N), dtype="int32"), device)
    result = t_evaluator(x, w, y)

    print("\nA x B :\n", y)

    # verify the correctness
    tvm.testing.assert_allclose(y.asnumpy(), np.dot(a_, b_.T), rtol=0)

    if (debug):
      t_func.export_library("tensorize_acc32.o")

compute()

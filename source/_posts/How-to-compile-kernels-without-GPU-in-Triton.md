---
title: How to Compile Triton Kernels Without GPU
tags:
  - triton
  - ml
  - ai
  - compiler
categories:
  - tech
date: 2024-12-25 17:50:42
---

Recently, I encountered a situation where I needed to contribute to Triton without access to any GPU.
The only device I had was my M3 Mac. After some experimentation, it turns out that Triton has a well-designed abstraction layer, and you don't need a GPU if you only want to work at the compiler level (i.e., MLIR and LLVM).

The method is present in the codebase, but it's not officially documented. I hope this guide will save someone else's time.

<!-- more -->

# Compile for NVIDIA GPU Target

```python
import os
import sys
import subprocess
import torch

import triton
import triton.language as tl
from triton.backends.compiler import GPUTarget
from triton.runtime.jit import JITFunction
import triton.compiler as tc

@triton.jit
def kernel(x_ptr, y_ptr, z_ptr, output_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid = tl.program_id(axis=0)
    block_start = pid * BLOCK_SIZE
    offsets = block_start + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements
    x = tl.load(x_ptr + offsets, mask=mask)
    y = tl.load(y_ptr + offsets, mask=mask)
    z = tl.load(z_ptr + offsets, mask=mask)

    output = tl.math.fma(x, y, z)
    tl.store(output_ptr + offsets, output, mask=mask)

src = tc.ASTSource(
    fn=kernel,
    constants={"BLOCK_SIZE": 1024},
    signature="*fp32,*fp32,*fp32,*fp32,i32,constexpr",
)

ret = triton.compile(src, target=GPUTarget("cuda", 80, 32))

for ir in ('ttir', 'ttgir', 'llir', 'ptx'):
    if ir not in ret.asm:
        continue
    print(f'NV IR: {ir}')
    print(ret.asm[ir])
    print('\n')
```

This example is a simplified version of the canonical compilation process. You need to get the AST of the Triton kernel and compile it for a specific target. For NVIDIA GPUs, use `GPUTarget("cuda", 80, 32)`. You can adjust the compute capability according to your hardware.

To obtain a valid AST, you need to provide the function signature. It’s essentially a list of argument types concatenated with commas. For instance, the arguments of our kernel are `x_ptr, y_ptr, z_ptr, output_ptr, n_elements, BLOCK_SIZE: tl.constexpr`. The first four arguments are pointers to fp32, so their types are `*fp32`. `n_elements` is an integer (`i32`), and `BLOCK_SIZE` is a constant (`constexpr`).

If you want to use other data types, such as fp16, modify the signature to `*fp16,*fp16,*fp16,*fp16,i32,constexpr`.

Once compiled, you can inspect the IRs, which are ttir, ttgir, llir, and ptx for NVIDIA GPUs.

## Get SASS Assembly
```python
print(f'NV IR: sass')
BIN_FILENAME = 'a.cubin'
if os.path.exists(BIN_FILENAME):
    os.remove(BIN_FILENAME)
pret = subprocess.run(
    ['ptxas', '-o', BIN_FILENAME, '--gpu-name', 'sm_80', '-'],
    input=ret.asm['ptx'],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)
if pret.returncode != 0:
    print(f'Failed to compile ptx, err: {pret.stderr}')
    sys.exit(-1)

pret = subprocess.run(
    ['nvdisasm', BIN_FILENAME],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)
if pret.returncode == 0:
    print(pret.stdout)
else:
    print(f'Failed to dis cubin, err: {pret.stderr}')
    sys.exit(-1)
```

However, the compiler cannot directly disassemble the cubin file to obtain the SASS assembly. You need to use the CUDA toolchain in the shell to do so.

# Compile for AMD GPU Target
```python
import os
import sys
import subprocess
import torch

import triton
import triton.language as tl
from triton.backends.compiler import GPUTarget
from triton.runtime.jit import JITFunction
import triton.compiler as tc

@triton.jit
def kernel(x_ptr, y_ptr, z_ptr, output_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid = tl.program_id(axis=0)
    block_start = pid * BLOCK_SIZE
    offsets = block_start + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements
    x = tl.load(x_ptr + offsets, mask=mask)
    y = tl.load(y_ptr + offsets, mask=mask)
    z = tl.load(z_ptr + offsets, mask=mask)

    output = tl.math.fma(x, y, z)
    tl.store(output_ptr + offsets, output, mask=mask)

src = tc.ASTSource(
    fn=kernel,
    constants={"BLOCK_SIZE": 1024},
    signature="*fp32,*fp32,*fp32,*fp32,i32,constexpr",
)

ret = triton.compile(src, target=GPUTarget("hip", 'gfx942', 32))
for ir in ('ttir', 'ttgir', 'llir', 'amdgcn', 'hsaco'):
    if ir not in ret.asm:
        continue
    print(f'AMD IR: {ir}')
    print(ret.asm[ir])
    print('\n')
```

Similarly, you can compile the Triton kernel for an AMD GPU target using `target=GPUTarget("hip", 'gfx942', 32)`. While the high-level IRs remain the same, the low-level IRs are amdgcn and hsaco.

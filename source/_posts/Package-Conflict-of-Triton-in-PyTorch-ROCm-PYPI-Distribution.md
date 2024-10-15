---
title: Package Conflict of Triton in PyTorch ROCm PYPI Distribution
date: 2024-10-14 22:58:39
tags:
---


# TL;DR

When you install PyTorch on the ROCm platform for an AMD GPU, a `pytorch-triton-rocm` package will be installed along with it. If you also install Triton at the same time, you may encounter a version conflict, which can be tricky to resolve.

<!-- more -->

According to [PyTorch](https://pytorch.org/get-started/locally/), you can use the following commands to install PyTorch for the ROCm backend using pip:

```bash
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1
```

In addition to the packages listed in the command, a `pytorch-triton-rocm` package will also be installed. This package is essentially a selected version of [Triton](https://github.com/triton-lang/triton), so the actual content of this package(in `site-packages`) is `triton/`, not `pytorch-triton-rocm/`.

In this case, if you then install a standalone Triton package, there is a potential conflict because both `pytorch-triton-rocm` and `triton` packages target the same `triton/` directory.

For example, you can't actually uninstall `triton` due to dependency issues. Instead, you will need to uninstall both `pytorch-triton-rocm` and `triton` to resolve this.

Hopefully this will help anyone in the same situation.

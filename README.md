# Ethos-U Vela Study

Hyungsun Yoo ([@shun-yoo](https://github.com/shun-yoo))

**NPU backend compiler study** — how Arm's Vela compiler turns a quantized neural network into commands for the Ethos-U55 NPU.

- Trace Vela's compilation pipeline (C++ core, Regor): graph optimisation → scheduling → memory allocation → command stream generation.
- Predict its per-layer decisions (striping, cascading, buffering, SRAM placement) and check them against Vela's output and Corstone-300 FVP runs.
- Implement and evaluate one policy change inside Vela (weight double-buffering or tensor allocation).

Notes are written in Korean.

- [SETUP.md](SETUP.md) — toolchain versions and environment setup
- [notes/](notes/)
  - [00 Compiler and model basics](notes/00-compiler-and-model-basics.md)
  - [01 Ethos-U55 NPU, Arm GCC, FVP](notes/01-ethos-u55-and-fvp.md)
  - [02 Eval Kit runtime](notes/02-eval-kit-runtime.md)
  - [03 Vela structure and pipeline](notes/03-vela-pipeline.md)
  - [04 Scheduling](notes/04-scheduling.md)

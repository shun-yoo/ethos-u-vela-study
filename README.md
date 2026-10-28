# Ethos-U Vela Study

**NPU backend compiler study** — how Arm's Vela compiler turns a quantized neural network into commands for the Ethos-U55 NPU.

- Trace Vela's compilation pipeline (C++ core, Regor): graph optimisation → scheduling → memory allocation → command stream generation.
- Predict its per-layer decisions (striping, cascading, buffering, SRAM placement) and check them against Vela's output and Corstone-300 FVP runs.
- Implement and evaluate one policy change inside Vela (weight double-buffering or tensor allocation).

Notes are written in Korean.

- [SETUP.md](SETUP.md) — toolchain versions and environment setup
- [notes/](notes/)
  - [00 Compiler and model basics](notes/00-compiler-and-model-basics.md)
  - [01 Ethos-U55 NPU, Arm GCC, FVP](notes/01-ethos-u55-and-fvp.md)
  - [02 Vela structure and pipeline](notes/02-vela-pipeline.md)
  - [03 Scheduling](notes/03-scheduling.md)

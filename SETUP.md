# 환경 구성

Linux x86_64 기준. 루트 권한은 필요 없다.

## 도구와 버전

| 도구 | 버전 | 용도 |
|---|---|---|
| Vela | 5.2.0 (`src/ethos-u-vela`, submodule) | 모델을 Ethos-U NPU용으로 컴파일 |
| Arm GNU Toolchain | 14.2.rel1 | Cortex-M용 C/C++ 크로스 컴파일 |
| Corstone-300 FVP | 11.27_42 | Cortex-M55 + Ethos-U55 가상 보드 |
| Python | 3.10–3.12 | Vela 실행 |

GCC와 FVP 버전은 ML Embedded Evaluation Kit 26.09의 `Dockerfile`에 맞췄다.

## 1. 저장소와 Vela

```bash
git clone --recurse-submodules <이 저장소 URL> ethos-u-vela-study
cd ethos-u-vela-study

python3 -m venv .venv
.venv/bin/pip install --upgrade pip
# C++ 코어(Regor)를 빌드한다. C++ 소스를 고친 뒤에는 이 명령을 다시 실행해야 반영된다.
CMAKE_BUILD_PARALLEL_LEVEL=32 .venv/bin/pip install -e src/ethos-u-vela
```

## 2. Arm GNU Toolchain

```bash
mkdir -p tools && cd tools
curl -L -o arm-gnu-toolchain.tar.xz \
  https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi.tar.xz
echo "62a63b981fe391a9cbad7ef51b17e49aeaa3e7b0d029b36ca1e9c3b2a9b78823  arm-gnu-toolchain.tar.xz" | sha256sum -c
tar -xf arm-gnu-toolchain.tar.xz && rm arm-gnu-toolchain.tar.xz
cd ..
```

## 3. Corstone-300 FVP

```bash
cd tools
curl -L -o FVP_Corstone_SSE-300.tgz \
  https://developer.arm.com/-/cdn-downloads/permalink/FVPs-Corstone-IoT/Corstone-300/FVP_Corstone_SSE-300_11.27_42_Linux64.tgz
echo "0dc9538041296b8d479249e6fa5aab74  FVP_Corstone_SSE-300.tgz" | md5sum -c
mkdir -p fvp-installer && tar -xf FVP_Corstone_SSE-300.tgz -C fvp-installer
# EULA에 동의하는 옵션이다. 내용은 설치 폴더의 license_terms/에 있다.
./fvp-installer/FVP_Corstone_SSE-300.sh --no-interactive --i-agree-to-the-contained-eula -d "$PWD/FVP_Corstone_SSE-300"
cd ..
```

- FVP 실행 파일은 `libpython3.9.so.1.0`에 링크되어 있다. 이 라이브러리는 FVP 패키지 안(`python/lib/`)에 들어 있다.
- 패키지의 `scripts/runtime.sh`가 이 위치를 잡아 주지만, `PYTHONHOME`을 바꾸기 때문에 터미널에 그대로 `source`하면 Vela(Python 3.12)가 깨질 수 있다.
- 그래서 `scripts/fvp-u55`가 FVP를 실행할 때만 이 설정을 적용한다.

## 4. 매 터미널마다

```bash
source scripts/env.sh   # .venv 활성화, arm-none-eabi-gcc와 fvp-u55를 PATH에 추가
```

확인:

```bash
vela --version                         # 5.2.0
arm-none-eabi-gcc --version | head -1  # 14.2.1
fvp-u55 --version                      # Fast Models [11.27.42 ...]
```

## 예제 모델

```bash
mkdir -p models
curl -L -o models/mobilenet_v2_1.0_224_INT8.tflite \
  https://github.com/ARM-software/ML-zoo/raw/master/models/image_classification/mobilenet_v2_1.0_224/tflite_int8/mobilenet_v2_1.0_224_INT8.tflite

vela models/mobilenet_v2_1.0_224_INT8.tflite \
  --accelerator-config ethos-u55-128 \
  --config Arm/vela.ini \
  --system-config Ethos_U55_High_End_Embedded \
  --memory-mode Shared_Sram \
  --output-dir models/out
```

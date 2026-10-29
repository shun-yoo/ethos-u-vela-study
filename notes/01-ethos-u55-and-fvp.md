# Ethos-U55 NPU와 실행 환경 (Arm GCC, FVP)

## 1. Ethos-U와 Vela 개요

**하드웨어**

- **NPU:** 신경망 연산(주로 행렬곱과 합성곱)을 전용으로 처리하는 가속기다.
- **Ethos-U:** Arm이 만든 소형 NPU다. 마이크로컨트롤러용 CPU(Cortex-M)에 붙어서, 양자화된 모델의 연산을 대신 처리한다. U55, U65, U85 세 종류가 있다.
- **SRAM:** 칩 안의 작고 빠른 메모리다. 칩 바깥의 Flash나 DRAM보다 훨씬 빠르지만 용량이 작다(수백 KB 수준).
- **DMA:** 연산기와 별도로 메모리 사이에서 데이터를 옮기는 장치다. 계산과 데이터 이동을 동시에 진행할 수 있게 해 준다.
- Ethos-U에는 GPU·CPU처럼 하드웨어가 알아서 데이터를 빠른 메모리에 두는 캐시가 사실상 없다. 그래서 무엇을 SRAM에 두고, 언제 DMA로 옮기고, 어떤 순서로 실행할지를 컴파일러가 실행 전에 정해야 한다.

**컴파일러: Vela**

- Ethos-U용 오픈소스 컴파일러다.
- 소스: https://gitlab.arm.com/artificial-intelligence/ethos-u/ethos-u-vela

| | 내용 |
|---|---|
| 입력 | int8(또는 int16)로 양자화된 .tflite 파일. TOSA 형식도 받는다. TOSA는 Arm이 주도하는 텐서 연산 표준 명세다. |
| 출력 | 새 .tflite 파일(`_vela.tflite`). NPU가 처리할 수 있는 연산 묶음은 Ethos-U 명령 목록(command stream)과 가중치를 담은 사용자 정의 연산 하나로 바뀐다. NPU가 지원하지 않는 연산은 원래대로 남는다. |
| 하지 않는 것 | CPU용 기계어는 만들지 않는다. |

**컴파일과 실행의 분리**

1. **컴파일 (실행 전, PC에서):** Vela가 .tflite를 읽고, SRAM 배치·DMA 시점·실행 순서를 정해 `_vela.tflite`를 만든다.
2. **실행 (기기에서):**
   - Cortex-M CPU에서 C 프로그램이 돈다. 이 프로그램은 마이크로컨트롤러용 추론 라이브러리인 TFLite Micro를 써서 `_vela.tflite`를 읽는다.
   - NPU용 연산을 만나면 그 명령 목록을 Ethos-U에 넘기고, NPU가 계산한다.
   - NPU가 지원하지 않는 연산은 CPU가 직접 계산한다.

## 2. 실행 환경: 두 컴파일러와 가상 보드(FVP)

**컴파일러는 두 개이고, 둘 다 서버(x86)에서 돈다.**

| 도구 | 대상 | 결과물 |
|---|---|---|
| Vela | NPU | `_vela.tflite` (NPU 명령 목록 + 가중치) |
| Arm GCC (`arm-none-eabi-gcc`) | CPU (Cortex-M) | `.axf` (Arm 기계어 실행 파일) |

- Arm GCC는 크로스 컴파일러다. x86에서 돌지만 Arm용 기계어를 만든다.

**전체 흐름**

| 순서 | 하는 일 | 도구 | 컴파일러로 치면 | 결과 |
|---|---|---|---|---|
| 1 | 모델 정의, 학습 | PyTorch / TensorFlow | 소스 프로그램 | 학습된 모델 (float32) |
| 2 | 그래프 파일로 변환, 그래프 정리, int8 양자화 | TFLite 변환기 | 프론트엔드 + 미들엔드 일부 | `모델.tflite` |
| 3 | NPU에 맞게 연산 변환, 스케줄링, SRAM 할당, NPU 명령 생성 | Vela | 미들엔드(하드웨어 맞춤) + 백엔드 | `모델_vela.tflite` |
| 4 | Eval Kit(CPU 프로그램 소스)과 `모델_vela.tflite`를 함께 빌드 | Arm GCC | CPU용 컴파일 | `.axf` |
| 5 | `.axf` 실행. Eval Kit 프로그램이 입력을 메모리에 올리고, NPU에 명령 목록 실행을 지시하고, 결과와 NPU 사이클을 출력 | FVP | — | 추론 결과, NPU 사이클 |

- 1~4는 서버에서, 5는 FVP에서 실행된다. 컴파일은 3과 4에서 끝나고, 5에서는 실행만 한다.
- `모델_vela.tflite`는 NPU 명령이 담긴 파일이라 혼자 실행되지 않는다. CPU에서 NPU를 구동하는 프로그램이 필요하고, Eval Kit(Arm ML Embedded Evaluation Kit)이 그 프로그램의 소스 코드다.
  - 앱: 입력 준비, 추론 호출, 결과 출력
  - TFLite Micro: 모델의 연산을 순서대로 실행한다. NPU용 연산은 드라이버로 넘긴다.
  - NPU 드라이버: 명령 목록을 Ethos-U55에 넘기고 완료를 기다린다.
  - 플랫폼 코드: 보드 초기화, 타이머, UART 등
- 모델은 `.axf` 안에 데이터로 들어간다. FVP에는 `.axf` 하나만 넣는다.
- `inference_runner` 앱은 입력을 무작위 값으로 채우고, 추론을 1번 실행하고, NPU 사이클(`NPU ACTIVE` 등)을 출력한다. 모델 파일은 cmake 옵션 `inference_runner_MODEL_PATH`로 지정한다.

**FVP = 가상 보드**

- 서버 위에서 도는 프로그램으로, Corstone-300 보드 한 장을 흉내 낸다.
- 구성: Cortex-M55 CPU, Ethos-U55 NPU, SRAM·Flash, 버스, UART(출력용) 등
- 한계(확인 필요): 계산 결과는 정확히 재현하지만, 사이클까지 실제 칩과 같다는 보장은 없는 것으로 알려져 있다. NPU 사이클을 평가 기준으로 쓰기 전에 문서로 확인해야 한다.

# Eval Kit과 실행 과정

(ML Embedded Evaluation Kit 26.09 기준)

## 1. Eval Kit의 역할

- `모델_vela.tflite`를 FVP에서 실행하고 NPU 사이클을 출력하는 CPU 프로그램의 소스 코드와 빌드 설정이다.
- 컴파일은 하지 않는다. 모델 컴파일은 Vela가, 프로그램 빌드는 Arm GCC가 한다.
- 이 저장소에서는 `inference_runner` 앱을 쓴다. 넣은 모델로 추론을 1번 실행하고 사이클을 출력한다. 모델 파일은 cmake 옵션 `inference_runner_MODEL_PATH`로 지정한다.

## 2. 폴더 구조

```
ml-embedded-evaluation-kit/
├── scripts/              빌드 설정 (서버에서 사용). 링커 스크립트가 코드·모델·arena를 메모리 어디에 둘지 정함
├── source/               Eval Kit이 만든 기기용 코드
│   ├── app/
│   │   ├── main/         보드 초기화 후 앱 실행
│   │   ├── use_case/     용도별 앱. (inference_runner: 추론 1번 실행 후 사이클 출력)
│   │   └── profiler/     측정 시작·끝의 카운터 값을 기록하고 출력
│   ├── lib/              TFLite Micro를 감싸 앱이 쓰기 쉽게 만든 층
│   └── hal/              보드 기능(출력, 타이머, NPU 초기화, 카운터 읽기)을 공통 함수로 감싼 층
└── dependencies/         
    ├── tensorflow/       TFLite Micro: 모델의 연산 목록을 순서대로 실행 (Google)
    ├── cmsis-nn/         CPU에서 계산하는 연산용 함수 (Arm)
    ├── core-driver/      NPU 드라이버: 명령 목록을 NPU에 넘기고 완료를 기다림 (Arm)
    ├── core-platform/    보드용 드라이버 모음. UART·타이밍 어댑터 드라이버를 씀 (Arm)
    ├── cmsis-6/          Cortex-M 공통 헤더: CPU 레지스터, 인터럽트 제어 (Arm)
    ├── cortex-dfp/       CPU 시작 코드: 전원이 켜지면 가장 먼저 실행 (Arm)
    ├── cmsis-dsp/        신호 처리 함수. 오디오 앱용 (Arm)
    └── avh/, executorch/ FVP 가상 입출력, 다른 추론 런타임. 쓰지 않음
```

## 3. 런타임 스택

FVP 위에서 도는 CPU 프로그램을 역할별 층으로 나눈 것이다. 위층이 아래층을 호출한다.

| 층 | 하는 일 | 폴더 |
|---|---|---|
| 앱 | 입력을 채우고, 추론을 호출하고, 사이클을 출력한다. | `source/app/` |
| 추론 런타임 | `모델_vela.tflite`의 연산 목록을 순서대로 실행한다. NPU용 연산은 드라이버로 넘긴다. | `source/lib/`, `dependencies/tensorflow/`, `dependencies/cmsis-nn/` |
| 드라이버 | 명령 목록을 NPU에 넘기고 완료를 기다린다. | `dependencies/core-driver/` |
| 플랫폼 (BSP) | 운영체제가 없으므로 운영체제가 하던 일을 직접 한다. CPU 시작, UART·타이머·NPU 설정 | `source/hal/`, `dependencies/cortex-dfp/`, `dependencies/cmsis-6/`, `dependencies/core-platform/` |
| 하드웨어 | | FVP (Cortex-M55 + Ethos-U55) |

## 4. 실행 순서

**A. 시작**

1. 시작 코드가 CPU를 준비한다. (`cortex-dfp`, `cmsis-6`)
2. `main()`이 실행된다. (`source/app/main`)
3. `hal_platform_init()`이 보드를 초기화한다. UART 출력과 NPU 드라이버를 준비한다. (`source/hal`, `core-platform`)

**B. 준비** (`source/app/use_case/inference_runner`)

4. 메모리 두 덩어리를 지정한다. 모델 데이터(`.axf` 안에 C 배열로 들어간 `모델_vela.tflite`)와 arena(텐서용 메모리, 기본 2MiB)
5. `model.Init()`이 TFLite Micro를 준비한다. (`source/lib`)
   - 연산 종류별로 실행할 함수를 등록한다. `ethos-u` 연산도 등록된다.
   - arena 안에 텐서 자리를 잡는다. 모자라면 `tensor allocation failed!`로 실패한다.

**C. 추론** (`source/app/use_case/inference_runner`)

6. 입력 텐서를 무작위 값으로 채운다.
7. 측정을 시작한다. (`source/app/profiler`)
8. `model.RunInference()` → TFLite Micro `Invoke()` (`source/lib` → `tensorflow`)
   - TFLite Micro는 `모델_vela.tflite`의 연산 목록을 순서대로 돌며, 연산마다 등록된 함수를 호출한다.
   - 계산 방법은 Vela가 컴파일할 때 이미 정해 두었고, TFLite Micro는 호출만 한다.
9. `ethos-u` 연산의 함수가 명령 목록과 메모리 영역 주소를 모아 드라이버를 호출한다. (`tensorflow`의 Ethos-U 커널)
10. 드라이버가 NPU에 명령 목록을 넘기고, NPU가 끝날 때까지 기다린다. (`core-driver`)
11. 측정을 끝낸다. (`source/app/profiler`)
12. NPU 사이클(`NPU ACTIVE` 등)을 UART로 출력한다. (`source/hal`)

```
앱: 입력 채움 → 측정 시작 → model.RunInference()
  └ TFLite Micro: 연산 목록을 순서대로 돎 (모든 연산이 NPU로 갔으면 ethos-u 하나)
      └ ethos-u 함수 → 드라이버: 명령 목록을 NPU에 넘기고 완료까지 대기
앱: 측정 끝 → 사이클 출력
```

## 5. 메모리 배치

마이크로컨트롤러에는 운영체제가 없어서, 실행 중에 메모리를 배정해 주는 주체가 없다. 그래서 메모리 위치는 실행 전에 정해 두어야 하는데, 한 번에 정해지지 않고 단계마다 나뉘어 정해진다.

컴파일할 때 Vela는 NPU가 쓰는 중간 결과를 텐서용 영역 안 어디에 둘지 정한다. 이때는 영역이 실제 메모리의 어디에 놓일지 아직 모르므로, 영역 시작점부터의 오프셋만 명령 목록에 적는다.

빌드할 때 링커는 보드 전용 링커 스크립트를 따라 코드와 데이터의 주소를 정한다. 텐서용 영역(배열)도 이때 SRAM의 특정 주소에 놓이므로, 영역의 실제 주소는 링크가 끝나면 확정된다. 하지만 링커에게 Vela의 명령 목록은 해석하지 않는 데이터일 뿐이라, 명령 목록 안에는 여전히 오프셋만 남아 있다.

그래서 실행할 때 런타임이 링크로 정해진 영역의 주소를 NPU에 알려 주고, NPU는 그 주소에 오프셋을 더해 실제 위치를 찾는다.

| 시점 | 누가 | 영역의 주소 | 명령 목록 안의 내용 |
|---|---|---|---|
| 컴파일 | Vela | 모름 | 오프셋만 적음 |
| 빌드 | 링커 | 정함 | 그대로 오프셋만 |
| 실행 | 런타임 | NPU에 전달 | NPU가 주소 + 오프셋으로 실제 위치를 찾음 |

Vela의 할당기가 내놓는 결과가 이 오프셋이다.

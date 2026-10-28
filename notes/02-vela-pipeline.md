# Vela 구조와 처리 순서

## 1. Vela의 내부: Python 부분과 C++ 엔진 Regor

(Vela 5.2.0 기준)

Vela는 Python 코드와 C++ 코드로 이루어져 있다. 이 중 C++로 된 컴파일 엔진을 **Regor**라고 부른다.

**`vela` 명령을 실행하면 일어나는 일**

1. **Python** (`ethosu/vela/vela.py`): 명령줄 옵션과 하드웨어 설정 파일(`vela.ini`: NPU 클럭, 메모리 속도 등)을 읽는다.
2. **C++ Regor:** Python이 `regor.compile(...)`을 호출한다. 모델 읽기, 그래프 최적화, 스케줄링, SRAM 할당, 명령 생성이 모두 여기서 일어난다.
3. **Python:** Regor가 돌려준 결과를 파일로 쓰고 성능 요약을 출력한다.

즉 Vela는 도구 전체의 이름이다. Python 부분은 입구와 출구 역할만 하고, 컴파일의 핵심은 Regor다.

**Python에서 C++를 쓰는 방식**

- 설치 과정(`pip install -e .`)에서 Regor의 C++ 소스가 cmake로 컴파일된다.
- 그 결과 공유 라이브러리 `ethosu/regor.cpython-312-x86_64-linux-gnu.so`가 만들어지고, Python은 이 파일을 모듈로 불러 쓴다.
- `-e`(editable) 설치의 의미:
  - Python 코드는 소스 폴더를 그대로 가리키므로, 고치면 바로 반영된다.
  - C++ 코드는 고친 뒤 `pip install -e .`를 다시 실행해 `.so`를 새로 빌드해야 반영된다.

**두 엔진이 생긴 경위**

| 버전 | 상황 |
|---|---|
| 4.0.0 이전 | 컴파일 엔진은 Python으로 된 것 하나뿐이었다. |
| 4.0.0 (2024년 9월) | 새 NPU인 Ethos-U85를 지원하면서 C++ 엔진 Regor가 추가됐다. 이때는 U85에만 Regor를 썼다. |
| 5.0.0 (2026년 2월) | U55와 U65도 Regor가 기본이 되었다. Python 엔진은 deprecated(사용 중단 예정)되어, `--debug-force-legacy-core` 옵션을 줘야만 쓸 수 있다. |

- Regor는 Python 엔진을 C++로 옮기며 확장한 것이라 구조가 거의 같다.
- 그래서 같은 이름의 파일이 양쪽에 있다: `scheduler`, `cascade_builder`, `live_range`, `hillclimb_allocator`, `tensor_allocator`, `high_level_command_stream_generator`

## 2. Regor 소스 구조

(`ethosu/regor/`)

| 폴더 | 내용 |
|---|---|
| `tflite/`, `tosa/` | 입력 모델 형식(TFLite, TOSA)을 읽어 내부 그래프로 만드는 부분 |
| `compiler/` | 컴파일 과정의 본체. 그래프 최적화, 스케줄러, cascading 묶음 결정, 생존 구간 계산, 메모리 할당기, 고수준 명령 생성 |
| `architecture/` | NPU별 부분. `ethosu55/`, `ethosu65/`, `ethosu85/`로 나뉘고, 하드웨어 레지스터 명령 생성, 가중치 인코딩, 성능 추정 등이 들어 있다. |
| `bindings/` | Python에서 C++를 호출할 수 있게 연결하는 코드 |
| `common/`, `include/` | 공통 유틸리티와 헤더 |
| `test/` | C++ 단위 테스트 |

`compiler/`에 나오는 용어는 다음과 같다.

- **스케줄러:** 각 연산을 어떤 단위로 나눠, 어떤 순서로, 어떤 메모리를 써서 실행할지 정한다.
- **cascading:** 연속된 여러 연산을 묶는다. 앞 연산의 출력을 전부 만든 뒤 넘기지 않고, 조금씩 만들어 바로 다음 연산에 넘긴다. 중간 결과 전체를 메모리에 둘 필요가 없어진다.
- **생존 구간**(live range): 각 텐서가 처음 만들어진 시점부터 마지막으로 쓰이는 시점까지의 구간이다. 생존 구간이 겹치지 않는 텐서끼리는 같은 메모리 공간을 재사용할 수 있다.
- **할당기:** 생존 구간을 바탕으로 각 텐서의 SRAM 주소를 정한다.

두 폴더의 역할 분담은 다음과 같다.

- `compiler/`는 어떤 NPU에도 공통인 결정 과정이다.
- `architecture/`는 그 결정에 쓰이는 하드웨어별 정보(연산기 크기, 메모리 특성 등)와 최종 명령 생성을 담당한다.
- 하드웨어 제약이 컴파일러의 결정에 어떻게 반영되는지는 이 두 폴더 사이의 관계를 보면 알 수 있다.

## 3. 처리 순서

(Vela 5.2.0, `ethosu/regor/compiler/compiler.cpp`의 `Compiler::Compile` → `CompileGraph` 기준)

| 순서 | 단계 | 코드 위치 |
|---|---|---|
| 1 | 읽기: TFLite를 내부 그래프로 변환 | `Compiler::LoadTflite`, `tflite/` |
| 2 | 검증 | `GraphValidator` |
| 3 | 그래프 최적화: TFLite 전용 → 공통 순서로 실행 | `GraphOptimiser` (`tflite_graph_optimiser`, `graphir_optimiser`) |
| 4 | 패킹: 그래프 연산을 스케줄러용 연산 목록으로 일렬화 | `SchedulerPacking` |
| 5 | 스케줄링: Min/Max 스케줄, cascade, 조각(stripe), 버퍼링, 가중치 인코딩 | `Scheduler::Process`, `cascade_builder` |
| 5-끝 | 주소 할당: 스케줄러의 마지막 단계 | `Scheduler::AllocateAddresses` → `live_range`, `tensor_allocator`, `hillclimb_allocator` |
| 6 | 상수 주소 할당, 전체 성능 계산(리포트용) | `AllocateReadOnlyAddresses`, `NetworkPerformance` |
| 7 | 명령 생성: 고수준 명령 → 하드웨어 레지스터 명령 | `HLCStreamGenerator` → `architecture/`의 register command stream 생성기 |
| 8 | 저장 | `Compiler::Store` |

- 할당은 독립 단계가 아니라 스케줄러 안에서 마지막에 호출된다. 스케줄링 중에도 생존 구간으로 메모리 사용량을 계속 계산한다(`UpdateOpMemorySnapshot`). 즉 스케줄링과 할당은 맞물려 있다.
- 성능 모델도 독립 단계가 아니다. 스케줄러가 후보를 판단할 때 불러 쓰고(`MeasureCycleCost`), 마지막에 리포트용으로 한 번 더 쓰인다.

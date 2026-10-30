# notes

Ethos-U55 NPU와 Vela 컴파일러를 공부하며 정리한 노트. 00~02는 기초와 실행 환경, 03부터는 Vela의 처리 순서를 따른다.

| 파일 | 내용 |
|---|---|
| [00-compiler-and-model-basics.md](00-compiler-and-model-basics.md) | 컴파일러 구조, 최적화의 한계(휴리스틱과 비용 추정), 모델 파일(.tflite) |
| [01-ethos-u55-and-fvp.md](01-ethos-u55-and-fvp.md) | Ethos-U55 NPU, 두 컴파일러(Vela, Arm GCC), 가상 보드(FVP) |
| [02-eval-kit-runtime.md](02-eval-kit-runtime.md) | Eval Kit의 역할, 런타임 스택, 실행 순서, 메모리 배치 |
| [03-vela-pipeline.md](03-vela-pipeline.md) | Vela와 C++ 엔진 Regor의 구조, 소스 위치, 처리 순서 |
| [04-scheduling.md](04-scheduling.md) | 스케줄러가 조각 크기·cascade·버퍼링을 정하는 방식 |

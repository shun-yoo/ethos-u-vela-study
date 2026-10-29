# notes

Ethos-U55 NPU와 Vela 컴파일러를 공부하며 정리한 노트. 파일 번호는 Vela의 처리 순서를 따른다.

| 파일 | 내용 |
|---|---|
| [00-compiler-and-model-basics.md](00-compiler-and-model-basics.md) | 컴파일러 구조, 최적화의 한계(휴리스틱과 비용 추정), 모델 파일(.tflite) |
| [01-ethos-u55-and-fvp.md](01-ethos-u55-and-fvp.md) | Ethos-U55 NPU, 두 컴파일러(Vela, Arm GCC), 가상 보드(FVP) |
| [02-vela-pipeline.md](02-vela-pipeline.md) | Vela와 C++ 엔진 Regor의 구조, 소스 위치, 처리 순서 |
| [03-scheduling.md](03-scheduling.md) | 스케줄러가 조각 크기·cascade·버퍼링을 정하는 방식 |

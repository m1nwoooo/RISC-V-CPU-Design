# RISC-V-CPU-Design
Design and implement a RISC-V CPU, then compile C code using the GCC compiler and load it as firmware for verification


## 🚀 프로젝트 개요

RISC-V RV32I 명령어 집합을 기반으로 한 32-bit 프로세서와 주변장치를 통합한 완전한 SoC 시스템입니다. 기본적인 ALU 연산부터 시작하여 점차 복잡한 모듈을 통합하는 Bottom-up 방식으로 설계되었으며, FPGA에 배포 가능한 형태로 구현되었습니다.

### 주요 특징

- **RV32I ISA**: 40개 instruction 구현

- **메모리 맵 I/O**: 주소 디코딩을 통한 효율적인 주변장치 제어
- **듀얼 포트 메모리**: inst fetch / data access 동시에 처리
- **FIFO 기반 통신**: UART TX/RX 버퍼링으로 안정적인 시리얼 통신
- **검증 완료**: Testbench를 통한 기능 검증 및 C 코드 실행 테스트

### 시스템 구조

<img width="1835" height="1011" alt="image" src="https://github.com/user-attachments/assets/fab14be0-9375-42e9-b46c-d896d29ea6f3" />

## 메모리 맵

| 주소 범위 | 장치 | 용도 |
|----------|------|------|
| `0x00000000 - 0x00001FFF` | RAM | 명령어 & 데이터 메모리 (8KB) |
| `0xFFFF1000 - 0xFFFF1FFF` | Keypad | 키패드 인터페이스 |
| `0xFFFF2000 - 0xFFFF2FFF` | GPIO | 7-세그먼트 & LED 제어 |
| `0xFFFF3000 - 0xFFFF3FFF` | UART | 시리얼 통신 (115200 bps) |
| `0xFFFF4000 - 0xFFFF4FFF` | SPI | SPI 마스터 (Mode 0) |

## 🛠️ 개발 과정 및 핵심 모듈


**구현 내용**:
- **ALU (alu.v)**: 10가지 연산 지원
  - 산술: ADD, SUB
  - 논리: AND, OR, XOR
  - 시프트: SLL, SRL, SRA
  - 비교: SLT, SLTU
  - 상태 플래그: N, Z, C, V

- **rv32i_cpu.v**: 단일 사이클 CPU 코어
  - Fetch: PC를 통한 명령어 읽기
  - Decode: 명령어 필드 분리 (opcode, funct3, funct7, rs1, rs2, rd)
  - Execute: ALU 연산 수행
  - Memory: Load/Store 처리
  - Write Back: 결과를 레지스터에 저장


**제어 신호 생성**:
```verilog
opcode → alusrc, regwrite, memwrite, alucontrol
```


**레지스터 맵** (Base: 0xFFFF4000):
```
+0x000: DATA[7:0]    (R/W)
+0x004: STATUS       (R: busy, tx_done)
+0x008: CTRL         (W: start)
```


####  CPU 동작 검증
**방법**: 
- RISC-V GCC로 컴파일한 바이너리를 메모리에 로드
- 파형 분석으로 PC, 레지스터 값 추적
- 최종 메모리 상태 확인
- 구체적인 검증 과정 및 결과는 pdf 파일 참조

### 타이밍

- **시스템 클럭**: 10 MHz (PLL 출력)
- **CPU 사이클**: 단일 사이클 실행 (대부분의 명령어)
- **메모리 접근**: 1 사이클
- **주변장치 접근**: 1~5 사이클 (장치별 상이)


## 향후 개선 방향

- [ ] 5-stage 파이프라인 구현
- [ ] 인터럽트 컨트롤러 (PLIC)
- [ ] 타이머/카운터 추가
- [ ] RV32IM 확장 (곱셈/나눗셈)
- [ ] 캐시 메모리
- [ ] DMA 컨트롤러






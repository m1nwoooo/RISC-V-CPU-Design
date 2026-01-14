# RISC-V-CPU-Design
Design and implement a RISC-V CPU, then compile C code using the GCC compiler and load it as firmware for verification


# RV32I SoC (System-on-Chip)

Verilog HDL을 사용한 RISC-V RV32I 프로세서 기반 SoC 설계 및 구현

![Block Diagram](rv32i_soc_diagram.png)

## 🚀 프로젝트 개요

RISC-V RV32I 명령어 집합을 기반으로 한 32-bit 프로세서와 주변장치를 통합한 완전한 SoC 시스템입니다. 기본적인 ALU 연산부터 시작하여 점차 복잡한 모듈을 통합하는 Bottom-up 방식으로 설계되었으며, FPGA에 배포 가능한 형태로 구현되었습니다.

### 주요 특징

- **완전한 RV32I ISA 지원**: 40개 명령어 구현 (산술, 논리, 분기, 점프, 메모리 접근)
- **통합된 주변장치**: GPIO, UART, SPI, Keypad 컨트롤러
- **메모리 맵 I/O**: 주소 디코딩을 통한 효율적인 주변장치 제어
- **듀얼 포트 메모리**: 명령어 페치와 데이터 접근 동시 처리
- **FIFO 기반 통신**: UART TX/RX 버퍼링으로 안정적인 시리얼 통신
- **검증 완료**: Testbench를 통한 기능 검증 및 C 코드 실행 테스트

### 시스템 구조

```
[외부 입력] → [PLL] → [클럭 생성]
                          ↓
    ┌──────────────────────────────────────┐
    │          RV32I_SoC                    │
    │                                       │
    │  [CPU Core] ← → [Address Decoder]   │
    │     ↕                    ↓            │
    │  [2-Port RAM]    [Peripherals]       │
    │                   • GPIO              │
    │                   • UART              │
    │                   • SPI               │
    │                   • Keypad            │
    └──────────────────────────────────────┘
                          ↓
              [7-Segment, LED, UART, SPI]
```

## 메모리 맵

| 주소 범위 | 장치 | 용도 |
|----------|------|------|
| `0x00000000 - 0x00001FFF` | RAM | 명령어 & 데이터 메모리 (8KB) |
| `0xFFFF1000 - 0xFFFF1FFF` | Keypad | 키패드 인터페이스 |
| `0xFFFF2000 - 0xFFFF2FFF` | GPIO | 7-세그먼트 & LED 제어 |
| `0xFFFF3000 - 0xFFFF3FFF` | UART | 시리얼 통신 (115200 bps) |
| `0xFFFF4000 - 0xFFFF4FFF` | SPI | SPI 마스터 (Mode 0) |

## 🛠️ 개발 과정 및 핵심 모듈

### Phase 1: ALU 및 레지스터 파일

**목표**: CPU의 핵심 연산 장치 구현

**구현 내용**:
- **ALU (alu.v)**: 10가지 연산 지원
  - 산술: ADD, SUB
  - 논리: AND, OR, XOR
  - 시프트: SLL, SRL, SRA
  - 비교: SLT, SLTU
  - 상태 플래그: N, Z, C, V

- **Register File (regfile.v)**: 32개 범용 레지스터
  - x0: 항상 0 (하드와이어드)
  - x1-x31: 32-bit 레지스터
  - 듀얼 포트 읽기, 단일 포트 쓰기

**검증**: 
- 다양한 입력 조합으로 연산 결과 확인
- 오버플로우 및 플래그 동작 테스트

### Phase 2: CPU 코어 구현

**목표**: RV32I 명령어 실행 파이프라인 구성

**구현 내용**:
- **rv32i_cpu.v**: 단일 사이클 CPU 코어
  - Fetch: PC를 통한 명령어 읽기
  - Decode: 명령어 필드 분리 (opcode, funct3, funct7, rs1, rs2, rd)
  - Execute: ALU 연산 수행
  - Memory: Load/Store 처리
  - Write Back: 결과를 레지스터에 저장

**지원 명령어**:
- **R-type**: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **I-type**: ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI, LB, LH, LW, LBU, LHU, JALR
- **S-type**: SB, SH, SW
- **B-type**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **U-type**: LUI, AUIPC
- **J-type**: JAL

**제어 신호 생성**:
```verilog
opcode → alusrc, regwrite, memwrite, alucontrol
```

**검증**:
- 각 명령어 타입별 단위 테스트
- 분기/점프 동작 확인
- Load/Store 바이트/하프워드 정렬 테스트

### Phase 3: 메모리 및 주소 디코더

**목표**: 메모리 시스템 및 I/O 주소 공간 분리

**구현 내용**:
- **2-Port RAM (ram2port_2048x32.v)**: 
  - Port A: 명령어 페치 (읽기 전용)
  - Port B: 데이터 접근 (읽기/쓰기)
  - 클럭 위상 분리 (clk90, clk180)로 타이밍 최적화

- **Address Decoder (Addr_Decoder.v)**:
  - 상위 비트 디코딩으로 칩 선택 신호 생성
  - 5개 장치 구분 (RAM, GPIO, Keypad, UART, SPI)

**검증**:
- 메모리 읽기/쓰기 동작 확인
- 주소 범위별 칩 선택 신호 검증
- 동시 접근 시나리오 테스트

### Phase 4: GPIO 및 디스플레이

**목표**: 시각적 출력 장치 제어

**구현 내용**:
- **GPIO.v**: 메모리 맵 I/O 방식
  - 6개 7-세그먼트 디스플레이 (HEX0~HEX5)
  - 4개 LED
  - 멀티플렉싱으로 순차 표시

**레지스터 맵** (Base: 0xFFFF2000):
```
+0x008: LEDS[3:0]
+0x00C: HEX0[6:0]
+0x010: HEX1[6:0]
...
+0x020: HEX5[6:0]
```

**검증**:
- 레지스터 읽기/쓰기 테스트
- 멀티플렉싱 타이밍 확인

### Phase 5: UART 통신 (FIFO 기반)

**목표**: 안정적인 시리얼 통신 구현

**구현 내용**:
- **UART.v**: Full-duplex 통신
  - TX/RX 독립 FIFO (16-deep)
  - Baudrate 생성기 (115200 bps)
  - FSM 기반 송수신 로직

- **FIFO.v**: 범용 동기식 FIFO
  - 파라미터화 가능 (깊이, 너비)
  - full/empty 상태 플래그

**동작 원리**:
```
[TX Path] CPU → TX FIFO → TX FSM → uart_tx
[RX Path] uart_rx → RX FSM → RX FIFO → CPU
```

**검증**:
- 문자열 전송 테스트
- FIFO 오버플로우/언더플로우 확인
- Baudrate 정확도 측정

### Phase 6: SPI 마스터

**목표**: SPI 장치와의 통신 인터페이스

**구현 내용**:
- **SPI.v**: Mode 0 (CPOL=0, CPHA=0)
  - MSB-first 전송
  - Full-duplex 동작
  - 클럭 분주기 (CLK_DIV=10)

**레지스터 맵** (Base: 0xFFFF4000):
```
+0x000: DATA[7:0]    (R/W)
+0x004: STATUS       (R: busy, tx_done)
+0x008: CTRL         (W: start)
```

**FSM 상태**:
```
IDLE → TRANS (8-bit 전송) → DONE
```

**검증**:
- Echo-back 테스트 (RX + 1 = TX)
- 타이밍 파형 분석
- 다중 트랜잭션 연속 처리

### Phase 7: 최종 시스템 통합

**목표**: 모든 모듈 통합 및 C 코드 실행

**구현 내용**:
- **RV32I_SoC.v**: Top-level 통합
  - PLL 기반 클럭 생성
  - 리셋 로직
  - 데이터 버스 멀티플렉서
  - 7-세그먼트 멀티플렉싱

**제어 흐름**:
```
rst → PLL lock → CPU 동작 → 주변장치 접근
```

**검증**:
- **C 코드 실행**: SPI 전송 예제 (c.c)
  ```c
  // SPI Echo Test
  rx = spi_transfer(tx);
  tx = rx + 1;
  ```
- **결과**: Testbench에서 PASS 확인
  ```
  Transaction #1: Sending 0x00, Received 0x01 → PASS
  Transaction #2: Sending 0x10, Received 0x11 → PASS
  ...
  ```

## 검증 방법

### Testbench 구조

각 모듈별 독립적인 테스트 환경:

```
testbench/
├── tb_RV32I_SoC.v      # 전체 시스템 테스트
│   ├── UART 출력 모니터링
│   └── SPI Echo 검증
```

### 시뮬레이션 실행

**Vivado Simulator**:
```bash
# 프로젝트 디렉토리에서
xvlog tb_RV32I_SoC.v RV32I_SoC.v [모든_모듈.v]
xelab tb_RV32I_SoC
xsim tb_RV32I_SoC -gui
```

**ModelSim**:
```bash
vlog -work work *.v
vsim -gui tb_RV32I_SoC
run -all
```

### 검증 시나리오

#### 1. UART 전송 테스트
**목표**: 메모리 쓰기 → UART 전송 확인

**방법**:
```verilog
// Testbench에서 UART 쓰기 감지
always @(posedge clk) begin
    if (cs_uart && mem_we)
        $write("%c", write_data[7:0]);  // 터미널 출력
end
```

**기대 결과**: "Hello World" 등 문자열 출력

#### 2. SPI Echo-back 테스트
**목표**: CPU가 받은 값 +1 해서 전송

**프로토콜**:
```
TB → 0x00 → CPU → 0x01 → TB (PASS)
TB → 0x10 → CPU → 0x11 → TB (PASS)
TB → 0x20 → CPU → 0x21 → TB (PASS)
```

**테스트벤치 로직**:
```verilog
// SPI Slave 시뮬레이션
always @(posedge spi_cs) begin
    if (slave_rx_data == prev_tx_data + 1)
        $display("PASS");
    else
        $display("FAIL");
end
```

**결과**: 모든 트랜잭션 PASS

#### 3. 명령어 실행 검증
**방법**: 
- RISC-V GCC로 컴파일한 바이너리를 메모리에 로드
- 파형 분석으로 PC, 레지스터 값 추적
- 최종 메모리 상태 확인

## 성능 특성

### 타이밍

- **시스템 클럭**: 10 MHz (PLL 출력)
- **CPU 사이클**: 단일 사이클 실행 (대부분의 명령어)
- **메모리 접근**: 1 사이클
- **주변장치 접근**: 1~5 사이클 (장치별 상이)

### 리소스 사용량 (예상)

| 구성 요소 | 수량 | 비고 |
|----------|------|------|
| 레지스터 (32-bit) | 31 | x1~x31 |
| RAM (32-bit) | 2048 | 8KB |
| ALU | 1 | 10가지 연산 |
| 주변장치 모듈 | 5 | GPIO, UART, SPI, Keypad, Decoder |

## 알려진 제한사항

1. **단일 사이클 설계**: 파이프라이닝 없음 (CPI = 1)
2. **메모리 크기**: 8KB로 제한
3. **인터럽트 미지원**: 폴링 방식으로만 I/O 처리
4. **캐시 없음**: 직접 메모리 접근
5. **UART Baudrate**: 컴파일 타임에 고정

## 향후 개선 방향

- [ ] 5-stage 파이프라인 구현
- [ ] 인터럽트 컨트롤러 (PLIC)
- [ ] 타이머/카운터 추가
- [ ] RV32IM 확장 (곱셈/나눗셈)
- [ ] 캐시 메모리
- [ ] DMA 컨트롤러

## 파일 구조

```
RV32I_SoC/
├── rtl/
│   ├── rv32i_cpu.v         # CPU 코어
│   ├── alu.v               # ALU
│   ├── regfile.v           # 레지스터 파일
│   ├── RV32I_SoC.v         # Top-level
│   ├── ram2port_2048x32.v  # 듀얼 포트 RAM
│   ├── Addr_Decoder.v      # 주소 디코더
│   ├── GPIO.v              # GPIO 컨트롤러
│   ├── UART.v              # UART (FIFO 포함)
│   ├── FIFO.v              # 범용 FIFO
│   ├── SPI.v               # SPI 마스터
│   └── Keypad.v            # 키패드 인터페이스
├── testbench/
│   └── tb_RV32I_SoC.v      # 전체 테스트벤치
├── software/
│   └── c.c                 # 예제 C 코드 (SPI 테스트)
└── README.md
```

## 참고 자료

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [RV32I Base Integer Instruction Set Manual](https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf)

## 저자

임베디드 시스템 / 컴퓨터 구조 설계 과제의 일환으로 제작




<img width="1835" height="1011" alt="image" src="https://github.com/user-attachments/assets/fab14be0-9375-42e9-b46c-d896d29ea6f3" />

# 🛠️ MoodNote Custom PCB (v1 PoC Architecture)

> **EasyEDA 기반 ESP32-S3 원보드(One-Board) 통합 IoT 회로 및 PCB 아트워크 설계 아카이브**  
> 본 디렉토리는 기성 모듈 채택 이전에 **단독 전원 관리, 디지털 오디오(I2S), 정밀 RTC, TF 카드, E-Paper 디스플레이 구동 회로를 밑바닥부터 직접 설계·검증한 하드웨어 R&D 결과물**입니다.

---

## 📸 하드웨어 설계 시각화 (Hardware Gallery)

| 회로도 (Full Schematic) | 3D PCB 완성 프리뷰 |
| :---: | :---: |
| Hardware/EasyEDA-Custom-PCB/images/01_schematic_v1.png | <img width="2160" height="1673" alt="02_pcb_3d_render" src="https://github.com/user-attachments/assets/5a1b0fbc-33ec-4706-96dc-12a820393632" /> |

| 2D 라우팅 및 풋프린트 배치 | Top Layer GND Copper Pour | Bottom Layer GND Copper Pour |
| :---: | :---: | :---: |
| <img width="2160" height="2158" alt="03_pcb_routing_layers" src="https://github.com/user-attachments/assets/c51f481f-9f1f-498d-9d7c-fb24bf3642bf" /> | <img width="2160" height="2091" alt="04_pcb_top_copper" src="https://github.com/user-attachments/assets/0a61ac0f-f918-48b3-b02e-48c8f5ba6b09" /> | <img width="2160" height="2091" alt="05_pcb_bottom_copper" src="https://github.com/user-attachments/assets/f3dba4bc-0de7-494f-92f3-0e4537122721" /> |

---

## 📐 1. 보드 스펙 및 물리적 규격 (Board Specification)

- **크기 (Dimensions)**: $60.0 \times 60.0\,\text{mm}$ (모서리 R값 가공 적용)
- **레이어 구성 (Layer)**: 2-Layer FR4 ($1.6\,\text{mm}$ 두께, $1\,\text{oz}$ Copper)
- **그라운드 플레인 (GND Pour)**: Top Layer & Bottom Layer 양면 Solid GND Pour 적용
- **DRC (Design Rule Check)**: **에러 0개 (Pass)** 달성 (배선 클리어런스, 최소 비아 홀 규격 준수)

---

## ⚡ 2. 회로 블록별 상세 설계 (Schematic Breakdown)

### ① MCU & 핵심 제어 (`U2`)
- **컨트롤러**: **ESP32-S3-WROOM-1** (2.4GHz Wi-Fi + BLE 5.0)
- **안테나 킵아웃 (Keepout)**: RF 신호 감쇠를 방지하기 위해 안테나 영역 하부의 모든 동박(Copper) 및 신호선 배제 처리 완료.

### ② 오디오 수음 블록 (`MIC1`)
- **소자**: **INMP441** (I2S 디지털 출력 MEMS 마이크)
- **인터페이스**: `I2S_SCK`(BCLK), `I2S_WS`(LRCK), `I2S_SD`(DOUT)
- **설계 고려사항**: 고주파 클럭 노이즈 유입을 차단하기 위해 디지털 마이크 전원단에 $0.1\,\mu\text{F}$ 디커플링 커패시터(`C8`)를 최단 거리 배치.

### ③ 전원 관리 및 충전 회로 (`U1`, `LDO1`)
- **충전 제어**: **TP4056** Li-Po 배터리 충전 IC + USB Type-C 16-Pin 리셉터클 (`USB1`)
  - $R_{\text{prog}}$ (`R1` = $2\,\text{k}\Omega$) 설정을 통해 충전 전류를 약 $580\,\text{mA}$로 제한하여 소형 배터리 발열 방지.
  - 충전 상태 표시 LED 핀(`CHRG#`, `STDBY#`) 인출.
- **전압 강하 (LDO)**: **ME6211C33M5G-N** ($3.3\,\text{V}$ 고정 출력, 저낙차 레귤레이터)
  - 입·출력단에 $10\,\mu\text{F}$ 탄탈/세라믹 커패시터(`C7`, `C6`)를 배치해 Wi-Fi 버스트 전류 소모 시의 리셋(Brownout) 방지.

### ④ 정밀 시계 및 타임스탬프 (`U4`, `X1`, `D1`, `U3`)
- **RTC IC**: **PCF85063AT/AY** ($I^2\text{C}$ 통신: `RTC_SDA`, `RTC_SCL`)
- **외장 크리스탈**: $32.768\,\text{kHz}$ 매칭 (`X1`)
- **듀얼 다이오드 전원 래치 (`D1: BAT54C`)**:
  - 메인 전원($3.3\,\text{V}$)이 공급될 때는 메인 전원으로 구동.
  - 전원 차단 시 하단 **CR1220 코인 배터리 (`U3`)**로 순간 절체되어 오프라인에서도 절대 시간을 보존.

### ⑤ 오프라인 대용량 저장소 (`CARD1`)
- **소켓**: **MicroSD (TF-PUSH)** 슬롯
- **통신 모드**: 고속 SPI 모드 (`SD_MISO`, `SD_MOSI`, `SD_SCK`, `SD_CS`)
- 음성 WAV 파일 실시간 버퍼링 및 오프라인 저장을 위한 다이렉트 버스 라우팅.

### ⑥ 디스플레이 인터페이스 (`FPC1`)
- **커넥터**: 8-Pin $0.5\,\text{mm}$ 피치 초슬림 FPC 소켓
- **타깃**: SPI 저전력 E-Paper 디스플레이 구동 (`EINK_DIN`, `EINK_CLK`, `EINK_CS`, `EINK_DC`, `EINK_RST`, `EINK_BUSY`)

---

## 💡 3. 핵심 엔지니어링 및 PCB 아트워크 트러블슈팅

1. **전면 LCD 안착 간섭 해소 (3D Clearance 개선)**
   - 기판 전면에 초슬림 E-Paper 패널이 평평하게 밀착될 수 있도록, 높이가 높은 THT 전해 커패시터(`C12`)와 코인 배터리 홀더(`U3`)를 **기판 바닥면(Bottom Layer)으로 관통 배치**하여 전면 단차를 $0\,\text{mm}$ 수준으로 평탄화.
2. **배선 직교 및 노이즈 격리 라우팅**
   - 상단(Top)은 수평/단거리 제어 라인 위주, 하단(Bottom)은 수직 신호선 및 대전류 전원 버스 라인으로 분리하여 신호 간 크로스토크(Crosstalk) 억제.
   - 고주파 SPI 클럭 라인과 I2S 오디오 라인이 전원 라인과 평행하게 달리지 않도록 직교 및 이격 배치.

---

## 🎯 4. 프로젝트 전환 사유 (Engineering Trade-off)

| 평가 항목 | EasyEDA Custom PCB v1 | 채택된 Waveshare 통합 모듈 | 채택 사유 (Decision) |
| :--- | :---: | :---: | :--- |
| **폼팩터** | $60 \times 60\,\text{mm}$ | **$53 \times 39.8\,\text{mm}$** | 키링/참(Charm) 착용형 포켓 사이즈 극대화 |
| **디스플레이** | FPC 외장 케이블 연결 | **온보드 패널 + 터치 일체형** | 별도 터치스크린 배선 불필요 및 기구 슬림화 |
| **오디오** | 마이크 단독 수음 | **ES8311 코덱 + 마이크 + 스피커** | 녹음뿐 아니라 음성 안내 피드백 기능 확장 |
| **일정/리스크** | PCB 제작·SMT 대기 3~4주 | **즉시 펌웨어/CAD 개발 착수** | 12월 마감 일정 내 소프트웨어/기구 완성도 집중 |

> **결론**: 본 커스텀 PCB 설계를 통해 **시스템 전원 구성, 노이즈 고려 아트워크, 센서/스토리지 인터페이스 검증 역량을 증명**하였으며, 최종 제품화 단계에서는 폼팩터 초소형화와 개발 속도를 위해 검증된 통합 모듈로 최적화 전환하였습니다.

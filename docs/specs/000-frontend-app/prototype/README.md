# 프로토타입 원본 (디자인 참고 SOT)

`000-frontend-app` 스펙의 **디자인 참고 자료**입니다. Flutter 구현은 이 프로토타입을 1:1 기준으로 삼습니다. (스펙: [../plan.md](../plan.md) · [../description.md](../description.md))

| 파일 | 설명 |
|------|------|
| `prototype.dc.html` | 프로토타입 본체(`.dc.html` 포맷). 13개 화면의 레이아웃·인라인 스타일(색·치수·텍스트)과 하단 `<script>`에 도메인 데이터·상태 머신이 모두 들어 있다. **구현 시 데이터·스타일의 단일 기준.** (원본 zip의 `다채로울지도-standalone-src.dc.html` — 템플릿·스크립트가 일관된 완성본을 채택. 동일 zip의 `다채로울지도.dc.html`은 travel 화면만 새 디자인으로 바뀐 미완성본이라 채택하지 않음. 두 파일의 도메인 데이터는 동일.) |
| `support.js` | `.dc.html`을 런타임에 React로 컴파일하는 dc-runtime(원본 보존용). |
| `assets/chungbuk-map.png` | 충북 지도 이미지(참고용). 실제 지도는 `prototype.dc.html`의 SVG path로 그린다. |
| `proposal.pdf` | 2026 관광데이터 활용 공모전 제안서(제품 컨텍스트). |
| `sketches/` | 초기 손그림 스케치 3장. |
| `screenshots/` | 원본 캡처(폰 프레임). |

## prototype.dc.html에서 포팅할 핵심 데이터 (하단 `<script>`)

- `REGION_NAME`·`MAP_ORDER`·`LABELS`·`MAP_PATHS` — 충북 11개 시·군 이름·순서·라벨 좌표·SVG path
- `TYPE` — 5개 퀘스트 유형(자연/미식/역사/액티비티/힐링) 색·이모지
- `VERIFY_LABEL` — 인증 방식(사진/GPS/OX퀴즈)
- `QUESTS` — 18개 퀘스트
- `DNA` — 5개 여행 DNA 유형
- `SURVEY` — 4문항 설문
- `mapFill(n)` — 진행도별 지도 색칠 규칙(0/1/2+)
- `class Component` — 화면 상태 머신·전이 로직(Riverpod로 이식)

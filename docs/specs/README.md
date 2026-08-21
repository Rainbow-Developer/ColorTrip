# 기능 스펙 (specs)

추가될 예정이거나 진행 중인 기능의 **계획·설명·구현 수준**을 기능 단위 폴더로 관리합니다.

- 폴더명: `{NNN}-{feature-name}` — `{NNN}`은 **5의 배수 prefix**(`000`, `005`, `010`, `015` …)로, 기존 최대 prefix + 5로 매깁니다. (사이에 끼워 넣을 여지를 두기 위함)
- 각 폴더에는 `plan.md`, `description.md`, `implementation.md` **3개 파일이 반드시** 있어야 하며, 반드시 [`docs/template/specs/`](../template/specs/)의 공통 템플릿을 복사해서 작성합니다.

```text
docs/specs/
├── 000-{feature-name}/
│   ├── plan.md
│   ├── description.md
│   └── implementation.md
└── 005-{feature-name}/
    ├── plan.md
    ├── description.md
    └── implementation.md
```

자세한 작성 규칙은 [docs/AGENT_GUIDE.md의 '기능 스펙'](../AGENT_GUIDE.md#기능-스펙-docsspecs)을 참고하세요.

## 현재 스펙

| Spec | 기능                                  |
|------|-------------------------------------|
| [000-frontend-app](000-frontend-app/) | Flutter 앱 프로토타입/프론트엔드               |
| [000-quest](000-quest/) | 충북 시·군 퀘스트 조회 기반                    |
| [005-auth-member](005-auth-member/) | 이전 Kakao 인증·JWT·7일 복구 정책 구현 기록 (035가 대체) |
| [010-journey](010-journey/) | 여행 생성·관리, DNA 추천, 퀘스트 인증(GPS·사진·퀴즈), 여정 완료 판정 |
| [010-travel-dna](010-travel-dna/) | 여행 DNA 설문·판정 |
| [015-database-migration](015-database-migration/) | 핵심 데이터 모델 Alembic 마이그레이션            |
| [020-backend-logging](020-backend-logging/) | 백엔드 공통 JSON 로깅·요청 로깅 |
| [025-travel-timeline](025-travel-timeline/) | 여행 타임라인 조회 API |
| [030-share-card](030-share-card/) | 여행 공유 카드 API |
| [035-kakao-auth-integration](035-kakao-auth-integration/) | Kakao Flutter SDK·JWT·온보딩·탈퇴 통합 인증 |
| [040-home-region-recommendation](040-home-region-recommendation/) | 홈 DNA 지역 추천 + 퀘스트 요약 (폐기 — 065가 대체, 구현 제거됨) |
| [045-quest-region-images](045-quest-region-images/) | 퀘스트·지역 이미지(TourAPI) |
| [050-quest-verification](050-quest-verification/) | 퀘스트 인증 3종(사진 AI·위치·QR) + 위치정보법 검토 |
| [055-journey-map-coloring](055-journey-map-coloring/) | 지도 채색 기준(퀘스트를 1개 이상 완료한 여행 수) |
| [040-domain-state-persistence](040-domain-state-persistence/) | 여행·퀘스트·지도·타임라인 서버 영속화와 앱 재시작 복원 |
| [060-share-native-experience](060-share-native-experience/) | 공유 카드 실사용화(지도 미리보기·네이티브 공유 시트·공유 랜딩 페이지) |
| [065-quest-recommendation-api](065-quest-recommendation-api/) | 서버 기반 미시작 지역·퀘스트 추천 API |
| [065-dev-https](065-dev-https/) | dev 서버 HTTPS 적용(Caddy + Let's Encrypt) |
| [070-municipal-open-api](070-municipal-open-api/) | 지자체 제공 오픈 API(지역 관광 통계, 서비스키 인증) |
| [075-privacy-policy-page](075-privacy-policy-page/) | Google Play 등록용 개인정보처리방침 공개 페이지 |
| [080-profile-image](080-profile-image/) | 프로필 이미지 등록·교체·제거(회원가입 선택 항목) |
| [080-timeline-journey-grouping](080-timeline-journey-grouping/) | 타임라인의 완료 퀘스트를 여행 단위로 그룹핑 |
| [085-journey-management](085-journey-management/) | 여행 이름·일정 수정과 삭제 |
| [085-legal-consent-compliance](085-legal-consent-compliance/) | 회원가입 법적 동의·개인정보 처리 정합화 |
| [090-realtime-tour-place-info](090-realtime-tour-place-info/) | 관광지 정보(이미지·소개문·운영정보) TourAPI 실시간 조회 전환 |

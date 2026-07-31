/// 백엔드 ↔ 프론트 카테고리 어휘 변환.
///
/// 5종 카테고리(자연·미식·역사문화·액티비티·힐링) 중 **액티비티만 값이 다르다** —
/// 백엔드 `Category`/`DnaType` enum은 `activity`, 프론트 정적 데이터·`questTypeStyles`·
/// `kDnaTypes`는 `active`를 쓴다. 변환 없이 백엔드 값을 그대로 쓰면 조회가 조용히 실패해
/// DNA가 기본값(자연 탐험)으로 대체되고 유형 라벨에 영문이 노출된다.
///
/// 서버에서 받은 카테고리·DNA 문자열은 UI로 넘기기 전에 [toAppCategory]를 거친다.
library;

const _serverToApp = <String, String>{'activity': 'active'};
const _appToServer = <String, String>{'active': 'activity'};

/// 서버 카테고리/DNA 값 → 앱 내부 값. 알 수 없는 값은 그대로 통과시킨다.
String toAppCategory(String serverValue) =>
    _serverToApp[serverValue] ?? serverValue;

/// 앱 내부 값 → 서버 카테고리/DNA 값(요청 파라미터로 보낼 때).
String toServerCategory(String appValue) => _appToServer[appValue] ?? appValue;

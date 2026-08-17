/// 백엔드 ↔ 프론트 카테고리 어휘 변환.
///
/// 5종 카테고리(자연·미식·역사문화·액티비티·힐링)의 표준 식별값은 백엔드와
/// 프론트 모두 `activity`를 쓴다. 예전 클라이언트/캐시에 남아 있을 수 있는 `active`만
/// `activity`로 보정한다.
///
/// 서버에서 받은 카테고리·DNA 문자열은 UI로 넘기기 전에 [toAppCategory]를 거친다.
library;

const _serverToApp = <String, String>{'active': 'activity'};
const _appToServer = <String, String>{'active': 'activity'};

/// 서버 카테고리/DNA 값 → 앱 내부 값. 알 수 없는 값은 그대로 통과시킨다.
String toAppCategory(String serverValue) =>
    _serverToApp[serverValue] ?? serverValue;

/// 앱 내부 값 → 서버 카테고리/DNA 값(요청 파라미터로 보낼 때).
String toServerCategory(String appValue) => _appToServer[appValue] ?? appValue;

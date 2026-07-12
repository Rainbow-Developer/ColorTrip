/// 18개 퀘스트 정적 데이터 — 프로토타입(QUESTS 상수)에서 그대로 옮김.
library;

import '../models/quest.dart';

const List<Quest> kQuests = [
  Quest(
    id: 'dy1',
    region: 'danyang',
    type: 'nature',
    title: '소백산 연화봉 전망대 인증',
    place: '소백산 연화봉',
    verify: 'photo',
    reward: 120,
    desc: '능선을 배경으로 인증샷을 남겨보세요. 정상에서 내려다보는 탁 트인 풍경이 기다리고 있습니다.',
    conditions: ['연화봉 전망대 도착 후 촬영', '능선이 보이도록 촬영'],
  ),
  Quest(
    id: 'dy2',
    region: 'danyang',
    type: 'nature',
    title: '도담삼봉에서 인생샷 남기기',
    place: '도담삼봉',
    verify: 'photo',
    reward: 80,
    desc: '남한강 위에 솟은 세 개의 봉우리를 배경으로 한 장 찍어보세요.',
    conditions: ['도담삼봉이 보이는 구도', '정자(석문) 포함 시 보너스'],
  ),
  Quest(
    id: 'dy3',
    region: 'danyang',
    type: 'food',
    title: '단양 마늘떡갈비 맛보기',
    place: '단양구경시장',
    verify: 'photo',
    reward: 70,
    desc: '단양의 명물 마늘 요리를 즐기고 음식 사진으로 기록하세요.',
    conditions: ['음식이 명확히 보이는 사진', '시장 내 식당에서 촬영'],
  ),
  Quest(
    id: 'cj1',
    region: 'cheongju',
    type: 'history',
    title: '직지 OX 퀴즈 풀기',
    place: '청주고인쇄박물관',
    verify: 'quiz',
    reward: 90,
    desc: '직지심체요절에 대한 상식 퀴즈에 도전하고 청주의 인쇄 문화를 알아보세요.',
    conditions: ['OX 퀴즈 정답 맞히기'],
    quizQuestion: '직지심체요절은 현존하는 세계 최초의 금속활자 인쇄본이다.',
    quizAnswer: true,
  ),
  Quest(
    id: 'cj2',
    region: 'cheongju',
    type: 'healing',
    title: '수암골 벽화마을 산책',
    place: '수암골',
    verify: 'photo',
    reward: 60,
    desc: '골목 가득한 벽화 사이를 걸으며 감성 한 컷을 남겨보세요.',
    conditions: ['벽화가 보이는 사진', '골목 풍경 포함'],
  ),
  Quest(
    id: 'cj3',
    region: 'cheongju',
    type: 'food',
    title: '서문시장 삼겹살 거리',
    place: '서문시장',
    verify: 'photo',
    reward: 60,
    desc: '청주식 삼겹살로 든든하게 배를 채우고 인증해보세요.',
    conditions: ['삼겹살 거리 내에서 촬영', '음식 사진 등록'],
  ),
  Quest(
    id: 'be1',
    region: 'boeun',
    type: 'history',
    title: '법주사 팔상전 지정 구도 촬영',
    place: '속리산 법주사',
    verify: 'photo',
    reward: 110,
    desc: '국보 팔상전을 지정된 구도로 담아보세요. 우리나라 유일의 목조 5층탑입니다.',
    conditions: ['팔상전 전체가 보이는 구도', '지정 포토존에서 촬영'],
  ),
  Quest(
    id: 'be2',
    region: 'boeun',
    type: 'active',
    title: '속리산 문장대 등반',
    place: '속리산 문장대',
    verify: 'gps',
    reward: 150,
    desc: '문장대 정상에서 GPS 위치 인증에 도전하세요!',
    conditions: ['문장대 정상 100m 이내 도달', 'GPS 위치 인증'],
  ),
  Quest(
    id: 'cu1',
    region: 'chungju',
    type: 'healing',
    title: '충주호 호반 드라이브',
    place: '충주호',
    verify: 'photo',
    reward: 70,
    desc: '잔잔한 호수를 따라 달리며 풍경 한 장을 남겨보세요.',
    conditions: ['충주호가 보이는 사진'],
  ),
  Quest(
    id: 'cu2',
    region: 'chungju',
    type: 'history',
    title: '탄금대에서 역사 한 조각',
    place: '탄금대',
    verify: 'photo',
    reward: 70,
    desc: '우륵이 가야금을 연주했다는 이야기가 깃든 절벽입니다.',
    conditions: ['탄금대 표지석 포함 촬영'],
  ),
  Quest(
    id: 'jc1',
    region: 'jecheon',
    type: 'nature',
    title: '청풍호반 케이블카',
    place: '청풍호반',
    verify: 'photo',
    reward: 90,
    desc: '케이블카에서 내려다보는 청풍호 전경을 담아보세요.',
    conditions: ['케이블카 탑승 인증', '호수 전경 촬영'],
  ),
  Quest(
    id: 'jc2',
    region: 'jecheon',
    type: 'healing',
    title: '의림지 야경 감상',
    place: '의림지',
    verify: 'photo',
    reward: 70,
    desc: '삼한시대 저수지의 고요한 밤 풍경을 기록하세요.',
    conditions: ['의림지 야경 촬영'],
  ),
  Quest(
    id: 'es1',
    region: 'eumseong',
    type: 'history',
    title: '큰바위얼굴조각공원 방문',
    place: '큰바위얼굴조각공원',
    verify: 'photo',
    reward: 60,
    desc: '세계 위인들의 조각상 사이에서 한 컷.',
    conditions: ['조각상 포함 촬영'],
  ),
  Quest(
    id: 'jh1',
    region: 'jincheon',
    type: 'history',
    title: '농다리 건너보기',
    place: '진천 농다리',
    verify: 'photo',
    reward: 60,
    desc: '천 년을 버틴 돌다리를 직접 건너보세요.',
    conditions: ['농다리 위 또는 앞에서 촬영'],
  ),
  Quest(
    id: 'jp1',
    region: 'jeungpyeong',
    type: 'active',
    title: '좌구산 천문대 별 관측',
    place: '좌구산천문대',
    verify: 'gps',
    reward: 80,
    desc: '밤하늘 아래에서 위치 인증에 도전하세요.',
    conditions: ['천문대 100m 이내 도달', 'GPS 위치 인증'],
  ),
  Quest(
    id: 'gs1',
    region: 'goesan',
    type: 'nature',
    title: '산막이옛길 트레킹',
    place: '산막이옛길',
    verify: 'photo',
    reward: 90,
    desc: '괴산호를 끼고 걷는 아름다운 숲길을 걸어보세요.',
    conditions: ['옛길 구간에서 촬영', '괴산호 풍경 포함'],
  ),
  Quest(
    id: 'oc1',
    region: 'okcheon',
    type: 'history',
    title: '정지용 생가 방문',
    place: '정지용 생가',
    verify: 'photo',
    reward: 60,
    desc: '시 향수의 고향에서 시인의 흔적을 만나보세요.',
    conditions: ['생가 입구에서 촬영'],
  ),
  Quest(
    id: 'yd1',
    region: 'yeongdong',
    type: 'food',
    title: '영동 와인터널 체험',
    place: '영동 와인터널',
    verify: 'photo',
    reward: 80,
    desc: '포도의 고장 영동에서 와인 한 잔을 즐겨보세요.',
    conditions: ['와인터널 내부에서 촬영'],
  ),
];

List<Quest> questsByRegion(String regionId) =>
    kQuests.where((q) => q.region == regionId).toList();

List<Quest> questsByType(String type) =>
    kQuests.where((q) => q.type == type).toList();

/// 해당 지역 퀘스트 중 가장 많은 유형 — 여행 목록 카드의 유형 배지에 쓰인다.
String? dominantTypeForRegion(String regionId) {
  final regionQuests = questsByRegion(regionId);
  if (regionQuests.isEmpty) return null;
  final counts = <String, int>{};
  for (final quest in regionQuests) {
    counts[quest.type] = (counts[quest.type] ?? 0) + 1;
  }
  var best = regionQuests.first.type;
  var max = -1;
  for (final quest in regionQuests) {
    final count = counts[quest.type]!;
    if (count > max) {
      max = count;
      best = quest.type;
    }
  }
  return best;
}

Quest? questById(String id) {
  for (final q in kQuests) {
    if (q.id == id) return q;
  }
  return null;
}

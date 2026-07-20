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
    desc:
        '구름 위로 펼쳐지는 능선, 그 끝에 서면 세상이 다르게 보여요. 정상에서만 만날 수 있는 탁 트인 풍경을 사진에 담아보세요.',
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
    desc:
        '단양팔경 제1경, 강물 위로 솟은 세 개의 봉우리에는 옛이야기가 흐릅니다. 남한강에 비친 도담삼봉을 인생샷으로 남겨보세요.',
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
    desc:
        '알싸한 단양 마늘로 재운 떡갈비 한 입이면 여행 피로가 싹 풀려요. 단양구경시장에서만 맛볼 수 있는 그 맛을 사진으로 남겨보세요.',
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
    desc:
        '구텐베르크보다 78년 앞선 세계 최초의 금속활자본, 그 주인공이 청주에 있다는 사실 알고 계셨나요? 직지의 비밀을 퀴즈로 확인해보세요.',
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
    desc: '드라마 속 그 골목, 알록달록한 벽화가 시간여행을 시켜줘요. 좁은 골목길을 걸으며 나만의 감성샷을 찾아보세요.',
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
    desc: '지글지글 굽는 소리와 냄새만으로도 배가 고파지는 곳, 서문시장 삼겹살 거리. 든든한 한 끼로 여행 에너지를 채워보세요.',
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
    desc: '우리나라에 하나뿐인 목조 5층탑, 국보 팔상전이 천년의 시간을 버티고 서 있어요. 지정된 구도로 그 웅장함을 담아보세요.',
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
    desc: '정상에 오르면 충북·경북·전북 세 도가 한눈에 보인다는 전설의 명당, 문장대. 두 발로 올라 정상 정복을 인증해보세요!',
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
    desc: '산과 물이 겹겹이 그려내는 충주호의 물그림, 창밖 풍경만으로도 힐링이 돼요. 드라이브 중 마주친 그 순간을 담아보세요.',
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
    desc:
        '가야금의 명인 우륵이 가락을 뜯었다고 전해지는 절벽, 지금도 강바람 소리가 가야금 선율처럼 들려요. 역사가 깃든 풍경을 사진에 담아보세요.',
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
    desc:
        '하늘 위로 올라 발 아래 펼쳐지는 청풍호, 마치 다른 세상에 온 듯한 풍경이에요. 케이블카 창밖 전경을 사진으로 남겨보세요.',
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
    desc: '삼한시대부터 이어져 온 저수지, 밤이 되면 물빛과 조명이 만나 더욱 특별해져요. 고요한 의림지의 야경을 담아보세요.',
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
    desc: '링컨부터 간디까지, 세계 위인들의 거대한 얼굴이 반겨주는 이색 공간이에요. 나만의 위인 사진을 남겨보세요.',
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
    desc: '고려시대에 놓였다고 전해지는 천 년의 돌다리, 지금 건너면 나도 그 역사의 일부가 돼요. 농다리를 직접 걸어보세요.',
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
    desc: '도심에선 볼 수 없는 은하수가 펼쳐지는 곳, 좌구산 천문대의 밤하늘 아래 서보세요. 위치 인증으로 방문을 남겨보세요.',
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
    desc: '물길과 숲길이 나란히 이어지는 산막이옛길, 걷는 내내 괴산호의 비치는 물빛이 따라와요. 걸으며 만난 풍경을 담아보세요.',
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
    desc:
        "'넓은 벌 동쪽 끝으로' 시작하는 시 '향수'의 그 고향, 정지용 시인의 발자취가 남아있는 곳이에요. 그 감성을 사진으로 느껴보세요.",
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
    desc: '동굴 저장고에서 숙성되는 포도의 고장 영동의 와인, 서늘한 터널 속에서 한 잔의 여유를 즐겨보세요.',
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

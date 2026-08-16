import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/verification.dart';

/// 추천 퀘스트를 요청·표시할 때 쓰는 기본 개수 — API 요청과 화면 표시 상한이 어긋나지
/// 않도록 하나의 값으로 공유한다.
const kRecommendedQuestSize = 3;

class DomainCatalog {
  const DomainCatalog({
    required this.regionIdsByKey,
    required this.regionKeysById,
    required this.questIdsByKey,
    required this.questKeysById,
  });

  final Map<String, String> regionIdsByKey;
  final Map<String, String> regionKeysById;
  final Map<String, String> questIdsByKey;
  final Map<String, String> questKeysById;

  String regionId(String key) => _required(regionIdsByKey, key, 'region');
  String questId(String key) => _required(questIdsByKey, key, 'quest');

  static String _required(Map<String, String> values, String key, String type) {
    final value = values[key];
    if (value == null) {
      throw StateError('Server catalog is missing $type key: $key');
    }
    return value;
  }
}

class DomainJourney {
  const DomainJourney({
    required this.id,
    required this.regionKey,
    required this.questKeys,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String regionKey;
  final List<String> questKeys;
  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final DateTime createdAt;
}

class DomainTimelineEntry {
  const DomainTimelineEntry({
    required this.questKey,
    required this.occurredAt,
    required this.photoUrl,
  });

  final String questKey;
  final DateTime occurredAt;
  final String? photoUrl;
}

class DomainRecommendedRegion {
  const DomainRecommendedRegion({
    required this.regionKey,
    required this.matchingQuestCount,
    required this.availableQuestCount,
  });

  final String regionKey;
  final int matchingQuestCount;
  final int availableQuestCount;
}

class DomainSnapshot {
  const DomainSnapshot({
    required this.catalog,
    required this.journeys,
    required this.completedQuestKeys,
    required this.regionProgress,
    required this.regionTripCount,
    required this.timeline,
  });

  final DomainCatalog catalog;
  final List<DomainJourney> journeys;
  final Set<String> completedQuestKeys;
  final Map<String, int> regionProgress;

  /// 지역별 완료 여행(여정) 수 — 지도 채색 기준([055-journey-map-coloring]).
  /// `/users/me/map`의 `completed_journey_count`를 그대로 담는다.
  final Map<String, int> regionTripCount;
  final List<DomainTimelineEntry> timeline;
}

class QuestVerification {
  const QuestVerification({
    required this.verified,
    this.reason,
    this.photoVerdict,
  });

  final bool verified;
  final String? reason;

  /// 사진 미션의 비전 판정 상세(신뢰도·사유·판정 제공자) — 그 밖의 미션에서는 null.
  /// 서버가 저장된 사진을 읽어 판정하고 응답에 함께 담아준다(KAN-73).
  final PhotoVerdict? photoVerdict;
}

abstract class DomainRepository {
  Future<DomainSnapshot> fetchSnapshot();

  Future<List<DomainRecommendedRegion>> fetchUnvisitedRecommendedRegions();

  Future<List<String>> fetchRecommendedQuestKeys({
    required String regionKey,
    int size = kRecommendedQuestSize,
  });

  Future<DomainJourney> createJourney({
    required String clientRequestId,
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  });

  Future<DomainJourney> updateJourney({
    required String journeyId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<void> deleteJourney({required String journeyId});

  Future<String> uploadPhoto(Uint8List bytes, {String mimeType = 'image/jpeg'});

  /// 퀘스트 인증 요청.
  ///
  /// **좌표 파라미터가 없는 것은 의도된 설계다** — 위치 인증은 단말에서 거리를 판정하고
  /// 좌표를 서버로 보내지 않는다. 좌표를 전송하면 저장 여부와 무관하게 위치정보법상
  /// 위치기반서비스사업 신고 대상이 된다
  /// (docs/specs/050-quest-verification/location-law-review.md, KAN-77).
  /// 서버도 gps 미션에 lat·lng이 오면 거절한다.
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  });
}

class DioDomainRepository implements DomainRepository {
  DioDomainRepository(this._dio);

  final Dio _dio;
  DomainCatalog? _catalog;

  @override
  Future<DomainSnapshot> fetchSnapshot() async {
    final catalog = await _loadCatalog();
    final results = await Future.wait<Object>([
      _fetchJourneys(catalog),
      _fetchCompletedQuestKeys(catalog),
      _fetchMapProgress(catalog),
      _fetchTimeline(),
    ]);
    final journeys = results[0] as List<DomainJourney>;
    final completed = results[1] as Set<String>;
    final mapProgress =
        results[2]
            as ({
              Map<String, int> completedCounts,
              Map<String, int> tripCounts,
            });
    final timeline = results[3] as List<DomainTimelineEntry>;
    completed.addAll(timeline.map((entry) => entry.questKey));
    return DomainSnapshot(
      catalog: catalog,
      journeys: journeys,
      completedQuestKeys: completed,
      regionProgress: mapProgress.completedCounts,
      regionTripCount: mapProgress.tripCounts,
      timeline: timeline,
    );
  }

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async {
    final catalog = await _loadCatalog();
    final items = await _fetchPaged('/regions/unvisited');
    final recommendations = <DomainRecommendedRegion>[];
    for (final item in items) {
      final regionKey = catalog.regionKeysById[item['id']];
      if (regionKey == null) continue;
      recommendations.add(
        DomainRecommendedRegion(
          regionKey: regionKey,
          matchingQuestCount: item['matching_quest_count'] as int,
          availableQuestCount: item['available_quest_count'] as int,
        ),
      );
    }
    return recommendations;
  }

  @override
  Future<List<String>> fetchRecommendedQuestKeys({
    required String regionKey,
    int size = kRecommendedQuestSize,
  }) async {
    final catalog = await _loadCatalog();
    final response = await _dio.get(
      '/quests/recommended',
      queryParameters: {
        'region_id': catalog.regionId(regionKey),
        'page': 1,
        'size': size,
      },
    );
    final items = (_data(response)['items'] as List)
        .cast<Map<String, dynamic>>();
    return items
        .map((item) => item['client_key'] as String?)
        .whereType<String>()
        .where(catalog.questIdsByKey.containsKey)
        .toList();
  }

  @override
  Future<DomainJourney> createJourney({
    required String clientRequestId,
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final catalog = await _loadCatalog();
    final response = await _dio.post(
      '/journeys',
      data: {
        'client_request_id': clientRequestId,
        'region_id': catalog.regionId(regionKey),
        'quest_ids': questKeys.map(catalog.questId).toList(),
        'title': title,
        'start_date': _date(startDate),
        'end_date': _date(endDate),
      },
    );
    return _journeyFromDetail(_data(response), catalog);
  }

  @override
  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) async {
    final catalog = await _loadCatalog();
    final response = await _dio.put(
      '/journeys/$journeyId/quests',
      data: {'quest_ids': questKeys.map(catalog.questId).toList()},
    );
    return _journeyFromDetail(_data(response), catalog);
  }

  @override
  Future<DomainJourney> updateJourney({
    required String journeyId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final catalog = await _loadCatalog();
    final response = await _dio.patch(
      '/journeys/$journeyId',
      data: {
        'title': title,
        'start_date': _date(startDate),
        'end_date': _date(endDate),
      },
    );
    return _journeyFromDetail(_data(response), catalog);
  }

  @override
  Future<void> deleteJourney({required String journeyId}) async {
    await _dio.delete('/journeys/$journeyId');
  }

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final mediaType = DioMediaType.parse(mimeType);
    final extension = switch (mediaType.subtype) {
      'png' => 'png',
      'webp' => 'webp',
      'heic' => 'heic',
      _ => 'jpg',
    };
    final response = await _dio.post(
      '/uploads/photo',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'quest.$extension',
          contentType: mediaType,
        ),
      }),
      // 최대 5MB를 실제로 전송하는 요청이다 — 기본 설정에는 sendTimeout이 없어
      // 느린 회선에서 전송이 정체되면 OS TCP 타임아웃까지 갇힌다(응답은 작은 JSON).
      options: Options(sendTimeout: const Duration(seconds: 30)),
    );
    return _data(response)['photo_url'] as String;
  }

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async {
    final catalog = await _loadCatalog();
    // 이 payload에는 위도·경도가 들어가지 않는다(좌표 비전송 불변식 — 인터페이스 주석 참고).
    final payload = <String, dynamic>{};
    if (journeyId != null) payload['journey_id'] = journeyId;
    if (photoUrl != null) payload['photo_url'] = photoUrl;
    if (answer != null) payload['answer'] = answer;
    if (qrPayload != null) payload['qr_payload'] = qrPayload;
    final response = await _dio.post(
      '/quests/${catalog.questId(questKey)}/verify',
      data: payload,
      // 사진 미션은 서버가 저장본을 읽어 비전 판정까지 수행하므로 응답이 늦는다
      // (본문은 작아서 receiveTimeout만 늘리면 된다 — 업로드 쪽은 sendTimeout 담당).
      options: photoUrl == null
          ? null
          : Options(receiveTimeout: const Duration(seconds: 30)),
    );
    final data = _data(response);
    final verdict = data['photo_verdict'];
    return QuestVerification(
      verified: data['verified'] as bool,
      reason: data['reason'] as String?,
      photoVerdict: verdict is Map<String, dynamic>
          ? PhotoVerdict.fromJson(verdict)
          : null,
    );
  }

  Future<DomainCatalog> _loadCatalog() async {
    final cached = _catalog;
    if (cached != null) return cached;

    final regionsResponse = await _dio.get('/regions');
    final regionItems = _envelope(regionsResponse.data) as List;
    final regionIdsByKey = <String, String>{};
    final regionKeysById = <String, String>{};
    for (final raw in regionItems.cast<Map<String, dynamic>>()) {
      final id = raw['id'] as String;
      final key = raw['slug'] as String?;
      if (key == null) continue;
      if (regionIdsByKey.containsKey(key) || regionKeysById.containsKey(id)) {
        throw StateError(
          'Server region catalog contains duplicate stable keys.',
        );
      }
      regionIdsByKey[key] = id;
      regionKeysById[id] = key;
    }

    final questItems = await _fetchPaged('/quests');
    final questIdsByKey = <String, String>{};
    final questKeysById = <String, String>{};
    for (final raw in questItems) {
      final id = raw['id'] as String;
      final key = raw['client_key'] as String?;
      if (key == null) continue;
      if (questIdsByKey.containsKey(key) || questKeysById.containsKey(id)) {
        throw StateError(
          'Server quest catalog contains duplicate stable keys.',
        );
      }
      questIdsByKey[key] = id;
      questKeysById[id] = key;
    }

    final catalog = DomainCatalog(
      regionIdsByKey: regionIdsByKey,
      regionKeysById: regionKeysById,
      questIdsByKey: questIdsByKey,
      questKeysById: questKeysById,
    );
    _catalog = catalog;
    return catalog;
  }

  Future<List<DomainJourney>> _fetchJourneys(DomainCatalog catalog) async {
    final items = await _fetchPaged('/journeys');
    final journeys = items
        .map((item) => _journeyFromList(item, catalog))
        .toList();
    journeys.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return journeys;
  }

  Future<Set<String>> _fetchCompletedQuestKeys(DomainCatalog catalog) async {
    final items = await _fetchPaged(
      '/users/me/progress',
      query: {'status': 'completed'},
    );
    return items
        .map((item) => catalog.questKeysById[item['quest_id']])
        .whereType<String>()
        .toSet();
  }

  Future<({Map<String, int> completedCounts, Map<String, int> tripCounts})>
  _fetchMapProgress(DomainCatalog catalog) async {
    final response = await _dio.get('/users/me/map');
    final items = (_envelope(response.data) as List)
        .cast<Map<String, dynamic>>();
    final completedCounts = <String, int>{};
    final tripCounts = <String, int>{};
    for (final item in items) {
      final key = catalog.regionKeysById[item['region_id']];
      if (key == null) continue;
      completedCounts[key] = item['completed_count'] as int;
      // 완료 여행(여정) 수 — 지도 채색 기준([055-journey-map-coloring]).
      tripCounts[key] = item['completed_journey_count'] as int? ?? 0;
    }
    return (completedCounts: completedCounts, tripCounts: tripCounts);
  }

  Future<List<DomainTimelineEntry>> _fetchTimeline() async {
    final response = await _dio.get('/users/me/timeline');
    final items = (_envelope(response.data) as List)
        .cast<Map<String, dynamic>>();
    return [
      for (final item in items)
        if (item['event_type'] == 'quest_completed' &&
            item['quest_client_key'] is String)
          DomainTimelineEntry(
            questKey: item['quest_client_key'] as String,
            occurredAt: DateTime.parse(item['occurred_at'] as String),
            photoUrl: item['photo_url'] as String?,
          ),
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchPaged(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    const size = 100;
    var page = 1;
    final items = <Map<String, dynamic>>[];
    while (true) {
      final response = await _dio.get(
        path,
        queryParameters: {...?query, 'page': page, 'size': size},
      );
      final data = _data(response);
      final pageItems = (data['items'] as List).cast<Map<String, dynamic>>();
      items.addAll(pageItems);
      final total = data['total'] as int;
      if (pageItems.isEmpty || items.length >= total) return items;
      page++;
    }
  }

  DomainJourney _journeyFromDetail(
    Map<String, dynamic> data,
    DomainCatalog catalog,
  ) {
    final regionId = data['region_id'] as String;
    final regionKey = catalog.regionKeysById[regionId];
    if (regionKey == null) {
      throw StateError('Journey references an unknown server region.');
    }
    final questKeys = <String>[];
    for (final item in (data['quests'] as List).cast<Map<String, dynamic>>()) {
      final key =
          item['client_key'] as String? ??
          catalog.questKeysById[item['quest_id']];
      if (key == null) {
        throw StateError('Journey references an unknown server quest.');
      }
      questKeys.add(key);
    }
    return DomainJourney(
      id: data['id'] as String,
      regionKey: regionKey,
      questKeys: questKeys,
      title: data['title'] as String?,
      startDate: _optionalDate(data['start_date']),
      endDate: _optionalDate(data['end_date']),
      status: data['status'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  DomainJourney _journeyFromList(
    Map<String, dynamic> data,
    DomainCatalog catalog,
  ) {
    final regionId = data['region_id'] as String;
    final regionKey = catalog.regionKeysById[regionId];
    if (regionKey == null) {
      throw StateError('Journey references an unknown server region.');
    }
    final questKeys = (data['quest_client_keys'] as List).cast<String>();
    for (final key in questKeys) {
      catalog.questId(key);
    }
    return DomainJourney(
      id: data['id'] as String,
      regionKey: regionKey,
      questKeys: questKeys,
      title: data['title'] as String?,
      startDate: _optionalDate(data['start_date']),
      endDate: _optionalDate(data['end_date']),
      status: data['status'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  static dynamic _envelope(dynamic response) =>
      (response as Map<String, dynamic>)['data'];

  static Map<String, dynamic> _data(Response<dynamic> response) =>
      _envelope(response.data) as Map<String, dynamic>;

  static DateTime? _optionalDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

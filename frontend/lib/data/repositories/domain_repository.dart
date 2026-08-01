import 'dart:typed_data';

import 'package:dio/dio.dart';

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

class DomainSnapshot {
  const DomainSnapshot({
    required this.catalog,
    required this.journeys,
    required this.completedQuestKeys,
    required this.regionProgress,
    required this.timeline,
  });

  final DomainCatalog catalog;
  final List<DomainJourney> journeys;
  final Set<String> completedQuestKeys;
  final Map<String, int> regionProgress;
  final List<DomainTimelineEntry> timeline;
}

class QuestVerification {
  const QuestVerification({required this.verified, this.reason});

  final bool verified;
  final String? reason;
}

abstract class DomainRepository {
  Future<DomainSnapshot> fetchSnapshot();

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

  Future<String> uploadPhoto(Uint8List bytes, {String mimeType = 'image/jpeg'});

  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? answer,
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
      _fetchRegionProgress(catalog),
      _fetchTimeline(),
    ]);
    final journeys = results[0] as List<DomainJourney>;
    final completed = results[1] as Set<String>;
    final regionProgress = results[2] as Map<String, int>;
    final timeline = results[3] as List<DomainTimelineEntry>;
    completed.addAll(timeline.map((entry) => entry.questKey));
    return DomainSnapshot(
      catalog: catalog,
      journeys: journeys,
      completedQuestKeys: completed,
      regionProgress: regionProgress,
      timeline: timeline,
    );
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
    );
    return _data(response)['photo_url'] as String;
  }

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? answer,
  }) async {
    final catalog = await _loadCatalog();
    final payload = <String, dynamic>{};
    if (journeyId != null) payload['journey_id'] = journeyId;
    if (latitude != null) payload['lat'] = latitude;
    if (longitude != null) payload['lng'] = longitude;
    if (photoUrl != null) payload['photo_url'] = photoUrl;
    if (answer != null) payload['answer'] = answer;
    final response = await _dio.post(
      '/quests/${catalog.questId(questKey)}/verify',
      data: payload,
    );
    final data = _data(response);
    return QuestVerification(
      verified: data['verified'] as bool,
      reason: data['reason'] as String?,
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

  Future<Map<String, int>> _fetchRegionProgress(DomainCatalog catalog) async {
    final response = await _dio.get('/users/me/map');
    final items = (_envelope(response.data) as List)
        .cast<Map<String, dynamic>>();
    final progress = <String, int>{};
    for (final item in items) {
      final key = catalog.regionKeysById[item['region_id']];
      if (key != null) progress[key] = item['completed_count'] as int;
    }
    return progress;
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

import 'dart:typed_data';

import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test('restores journeys, progress, map, and timeline with stable keys', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.httpClientAdapter = _Adapter((options) {
      switch (options.path) {
        case '/regions':
          return _json(
            '{"data":[{"id":"legacy-region","name":"기존 지역","slug":null,'
            '"area_code":null,"center_lat":null,"center_lng":null},'
            '{"id":"region-uuid","name":"단양군","slug":"danyang",'
            '"area_code":"2","center_lat":null,"center_lng":null}]}',
          );
        case '/quests':
          return _json(
            '{"data":{"items":[{"id":"legacy-quest","region_id":"legacy-region",'
            '"client_key":null,"title":"기존 퀘스트","category":"nature",'
            '"mission_type":"quiz","lat":null,"lng":null,"thumbnail_url":null},'
            '{"id":"quest-uuid","region_id":"region-uuid",'
            '"client_key":"dy1","title":"퀘스트","category":"nature",'
            '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null}],'
            '"page":1,"size":100,"total":2}}',
          );
        case '/journeys':
          return _json(
            '{"data":{"items":[{"id":"journey-uuid","region_id":"region-uuid",'
            '"title":"단양 여행","start_date":"2026-07-20","end_date":"2026-07-22",'
            '"status":"completed","progress":{"completed":1,"total":1},'
            '"quest_client_keys":["dy1"],'
            '"created_at":"2026-07-20T09:00:00+09:00","completed_at":"2026-07-21T10:00:00+09:00"}],'
            '"page":1,"size":100,"total":1}}',
          );
        case '/users/me/progress':
          return _json(
            '{"data":{"items":[{"id":"progress-uuid","quest_id":"quest-uuid",'
            '"journey_id":"journey-uuid","status":"completed","photo_url":"/uploads/photos/x.jpg",'
            '"completed_at":"2026-07-21T10:00:00+09:00","created_at":"2026-07-20T09:00:00+09:00",'
            '"quest_title":"퀘스트","quest_category":"nature","quest_thumbnail_url":null}],'
            '"page":1,"size":100,"total":1}}',
          );
        case '/users/me/map':
          return _json(
            '{"data":[{"region_id":"region-uuid","region_name":"단양군",'
            '"completed_count":1,"first_colored_at":"2026-07-21T10:00:00+09:00"}]}',
          );
        case '/users/me/timeline':
          return _json(
            '{"data":[{"id":"timeline-uuid","event_type":"quest_completed",'
            '"title":"퀘스트","region_name":"단양군","quest_id":"quest-uuid",'
            '"quest_client_key":"dy1","photo_url":"/uploads/photos/x.jpg",'
            '"occurred_at":"2026-07-21T10:00:00+09:00"}]}',
          );
        default:
          throw StateError('unexpected ${options.method} ${options.path}');
      }
    });

    final snapshot = await DioDomainRepository(dio).fetchSnapshot();

    expect(snapshot.completedQuestKeys, {'dy1'});
    expect(snapshot.catalog.regionIdsByKey, {'danyang': 'region-uuid'});
    expect(snapshot.catalog.questIdsByKey, {'dy1': 'quest-uuid'});
    expect(snapshot.regionProgress, {'danyang': 1});
    expect(snapshot.journeys.single.questKeys, ['dy1']);
    expect(snapshot.timeline.single.questKey, 'dy1');
    expect(snapshot.timeline.single.photoUrl, '/uploads/photos/x.jpg');
  });

  test('creates a journey using server UUIDs and client idempotency key', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    late Map<String, dynamic> requestBody;
    dio.httpClientAdapter = _Adapter((options) {
      if (options.path == '/regions') {
        return _json(
          '{"data":[{"id":"region-uuid","name":"단양군","slug":"danyang",'
          '"area_code":"2","center_lat":null,"center_lng":null}]}',
        );
      }
      if (options.path == '/quests') {
        return _json(
          '{"data":{"items":[{"id":"quest-uuid","region_id":"region-uuid",'
          '"client_key":"dy1","title":"퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null}],'
          '"page":1,"size":100,"total":1}}',
        );
      }
      if (options.path == '/journeys') {
        requestBody = Map<String, dynamic>.from(options.data as Map);
        return _json(
          '{"data":{"id":"journey-uuid","region_id":"region-uuid","title":"단양 여행",'
          '"start_date":"2026-07-20","end_date":"2026-07-22","status":"in_progress",'
          '"progress":{"completed":0,"total":1},"created_at":"2026-07-20T09:00:00+09:00",'
          '"completed_at":null,"quests":[{"quest_id":"quest-uuid","client_key":"dy1",'
          '"title":"퀘스트","category":"nature","mission_type":"photo",'
          '"thumbnail_url":null,"sort_order":0,"progress_status":null}]}}',
          status: 201,
        );
      }
      throw StateError('unexpected ${options.method} ${options.path}');
    });
    final repository = DioDomainRepository(dio);

    await repository.createJourney(
      clientRequestId: 'request-uuid',
      regionKey: 'danyang',
      questKeys: const ['dy1'],
      title: '단양 여행',
      startDate: DateTime(2026, 7, 20),
      endDate: DateTime(2026, 7, 22),
    );

    expect(requestBody, {
      'client_request_id': 'request-uuid',
      'region_id': 'region-uuid',
      'quest_ids': ['quest-uuid'],
      'title': '단양 여행',
      'start_date': '2026-07-20',
      'end_date': '2026-07-22',
    });
  });

  test('maps recommendation API UUIDs to static region and quest keys', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.httpClientAdapter = _Adapter((options) {
      if (options.path == '/regions') {
        return _json(
          '{"data":[{"id":"region-uuid","name":"단양군","slug":"danyang",'
          '"area_code":"2","center_lat":null,"center_lng":null}]}',
        );
      }
      if (options.path == '/quests') {
        return _json(
          '{"data":{"items":[{"id":"quest-uuid","region_id":"region-uuid",'
          '"client_key":"dy1","title":"퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null}],'
          '"page":1,"size":100,"total":1}}',
        );
      }
      if (options.path == '/regions/unvisited') {
        return _json(
          '{"data":{"items":[{"id":"region-uuid","slug":"danyang",'
          '"name":"단양군","area_code":"2","center_lat":null,"center_lng":null,'
          '"matching_quest_count":1,"available_quest_count":3}],'
          '"applied_category":"nature","page":1,"size":100,"total":1}}',
        );
      }
      if (options.path == '/quests/recommended') {
        expect(options.queryParameters, {
          'region_id': 'region-uuid',
          'page': 1,
          'size': 2,
        });
        return _json(
          '{"data":{"items":[{"id":"quest-uuid","region_id":"region-uuid",'
          '"client_key":"dy1","title":"퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null,'
          '"is_dna_match":true}],"applied_category":"nature",'
          '"page":1,"size":2,"total":1}}',
        );
      }
      throw StateError('unexpected ${options.method} ${options.path}');
    });
    final repository = DioDomainRepository(dio);

    final regions = await repository.fetchUnvisitedRecommendedRegions();
    final quests = await repository.fetchRecommendedQuestKeys(
      regionKey: 'danyang',
      size: 2,
    );

    expect(regions.single.regionKey, 'danyang');
    expect(regions.single.matchingQuestCount, 1);
    expect(regions.single.availableQuestCount, 3);
    expect(quests, ['dy1']);
  });

  test('uses three recommendation quests without fetching later pages', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    var recommendedCalls = 0;
    dio.httpClientAdapter = _Adapter((options) {
      if (options.path == '/regions') {
        return _json(
          '{"data":[{"id":"region-uuid","name":"단양군","slug":"danyang",'
          '"area_code":"2","center_lat":null,"center_lng":null}]}',
        );
      }
      if (options.path == '/quests') {
        return _json(
          '{"data":{"items":[{"id":"quest-1","region_id":"region-uuid",'
          '"client_key":"dy1","title":"첫 퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null},'
          '{"id":"quest-2","region_id":"region-uuid",'
          '"client_key":"dy2","title":"둘째 퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null}],'
          '"page":1,"size":100,"total":2}}',
        );
      }
      if (options.path == '/quests/recommended') {
        recommendedCalls++;
        expect(options.queryParameters, {
          'region_id': 'region-uuid',
          'page': 1,
          'size': 3,
        });
        return _json(
          '{"data":{"items":[{"id":"quest-1","region_id":"region-uuid",'
          '"client_key":"dy1","title":"첫 퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null,'
          '"is_dna_match":true},{"id":"quest-2","region_id":"region-uuid",'
          '"client_key":"dy2","title":"둘째 퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null,'
          '"is_dna_match":true}],"applied_category":"nature",'
          '"page":1,"size":3,"total":3}}',
        );
      }
      throw StateError('unexpected ${options.method} ${options.path}');
    });

    final quests = await DioDomainRepository(
      dio,
    ).fetchRecommendedQuestKeys(regionKey: 'danyang');

    expect(quests, ['dy1', 'dy2']);
    expect(recommendedCalls, 1);
  });

  test('submits server quest UUID and real verification evidence', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    late RequestOptions verificationRequest;
    dio.httpClientAdapter = _Adapter((options) {
      if (options.path == '/regions') {
        return _json(
          '{"data":[{"id":"region-uuid","name":"단양군","slug":"danyang",'
          '"area_code":"2","center_lat":null,"center_lng":null}]}',
        );
      }
      if (options.path == '/quests') {
        return _json(
          '{"data":{"items":[{"id":"quest-uuid","region_id":"region-uuid",'
          '"client_key":"dy4","title":"GPS 퀘스트","category":"activity",'
          '"mission_type":"gps","lat":"36.9","lng":"128.3","thumbnail_url":null}],'
          '"page":1,"size":100,"total":1}}',
        );
      }
      if (options.path == '/quests/quest-uuid/verify') {
        verificationRequest = options;
        return _json(
          '{"data":{"verified":true,"reason":null,"progress":{'
          '"id":"progress-uuid","quest_id":"quest-uuid","journey_id":"journey-uuid",'
          '"status":"completed","photo_url":null,'
          '"completed_at":"2026-07-21T10:00:00+09:00",'
          '"created_at":"2026-07-21T10:00:00+09:00"}}}',
        );
      }
      throw StateError('unexpected ${options.method} ${options.path}');
    });

    final result = await DioDomainRepository(dio).verifyQuest(
      questKey: 'dy4',
      journeyId: 'journey-uuid',
      latitude: 36.977,
      longitude: 128.337,
    );

    expect(result.verified, isTrue);
    expect(verificationRequest.method, 'POST');
    expect(Map<String, dynamic>.from(verificationRequest.data as Map), {
      'journey_id': 'journey-uuid',
      'lat': 36.977,
      'lng': 128.337,
    });
  });

  test('uploads photo bytes using the picker-provided MIME type', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    late RequestOptions uploadRequest;
    dio.httpClientAdapter = _Adapter((options) {
      uploadRequest = options;
      return _json(
        '{"data":{"photo_url":"/uploads/photos/2026/07/uploaded.jpg"}}',
        status: 201,
      );
    });

    final photoUrl = await DioDomainRepository(dio).uploadPhoto(
      Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      mimeType: 'image/png',
    );

    expect(uploadRequest.path, '/uploads/photo');
    expect(uploadRequest.method, 'POST');
    final form = uploadRequest.data as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'quest.png');
    expect(form.files.single.value.contentType.toString(), 'image/png');
    expect(photoUrl, '/uploads/photos/2026/07/uploaded.jpg');
  });

  test(
    'stops pagination when a later page is empty before the reported total',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      var journeyPageRequests = 0;
      dio.httpClientAdapter = _Adapter((options) {
        switch (options.path) {
          case '/regions':
            return _json(
              '{"data":[{"id":"region-uuid","name":"단양군","slug":"danyang",'
              '"area_code":"2","center_lat":null,"center_lng":null}]}',
            );
          case '/quests':
            return _json('{"data":{"items":[],"page":1,"size":100,"total":0}}');
          case '/journeys':
            journeyPageRequests++;
            return _json(
              journeyPageRequests == 1
                  ? '{"data":{"items":[{"id":"journey-uuid","region_id":"region-uuid",'
                        '"title":null,"start_date":null,"end_date":null,"status":"in_progress",'
                        '"progress":{"completed":0,"total":0},"quest_client_keys":[], '
                        '"created_at":"2026-07-20T09:00:00+09:00","completed_at":null}],'
                        '"page":1,"size":100,"total":2}}'
                  : '{"data":{"items":[],"page":2,"size":100,"total":2}}',
            );
          case '/users/me/progress':
            return _json('{"data":{"items":[],"page":1,"size":100,"total":0}}');
          case '/users/me/map':
          case '/users/me/timeline':
            return _json('{"data":[]}');
          default:
            throw StateError('unexpected ${options.method} ${options.path}');
        }
      });

      final snapshot = await DioDomainRepository(dio).fetchSnapshot();

      expect(snapshot.journeys, hasLength(1));
      expect(journeyPageRequests, 2);
    },
  );

  test('replaces a journey quest set with server UUIDs', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    late Map<String, dynamic> requestBody;
    dio.httpClientAdapter = _Adapter((options) {
      if (options.path == '/regions') {
        return _json(
          '{"data":[{"id":"region-uuid","name":"단양군","slug":"danyang",'
          '"area_code":"2","center_lat":null,"center_lng":null}]}',
        );
      }
      if (options.path == '/quests') {
        return _json(
          '{"data":{"items":[{"id":"quest-uuid","region_id":"region-uuid",'
          '"client_key":"dy1","title":"퀘스트","category":"nature",'
          '"mission_type":"photo","lat":null,"lng":null,"thumbnail_url":null}],'
          '"page":1,"size":100,"total":1}}',
        );
      }
      if (options.path == '/journeys/journey-uuid/quests') {
        requestBody = Map<String, dynamic>.from(options.data as Map);
        return _json(
          '{"data":{"id":"journey-uuid","region_id":"region-uuid","title":null,'
          '"start_date":null,"end_date":null,"status":"in_progress",'
          '"progress":{"completed":0,"total":1},"created_at":"2026-07-20T09:00:00+09:00",'
          '"completed_at":null,"quests":[{"quest_id":"quest-uuid","client_key":"dy1",'
          '"title":"퀘스트","category":"nature","mission_type":"photo",'
          '"thumbnail_url":null,"sort_order":0,"progress_status":null}]}}',
        );
      }
      throw StateError('unexpected ${options.method} ${options.path}');
    });

    await DioDomainRepository(
      dio,
    ).replaceJourneyQuests(journeyId: 'journey-uuid', questKeys: const ['dy1']);

    expect(requestBody, {
      'quest_ids': ['quest-uuid'],
    });
  });
}

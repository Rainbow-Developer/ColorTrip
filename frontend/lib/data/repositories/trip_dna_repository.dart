import 'package:dio/dio.dart';
import '../models/trip_dna_question.dart';
import '../static/trip_dna_data.dart';

/// 초기 설문 및 여행 DNA 관련 API 연동 레포지토리
abstract class TripDnaRepository {
  Future<List<TripDnaQuestion>> questions();
  Future<Map<String, dynamic>> submitReplies(List<Map<String, String>> replies);
}

class StaticTripDnaRepository implements TripDnaRepository {
  const StaticTripDnaRepository();

  @override
  Future<List<TripDnaQuestion>> questions() async {
    // 딜레이를 주어 실제 API처럼 보이도록 처리
    await Future.delayed(const Duration(milliseconds: 300));
    return kTripDnaQuestions;
  }

  @override
  Future<Map<String, dynamic>> submitReplies(
    List<Map<String, String>> replies,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // 로컬 Mock 연산: 기존 로직처럼 최다 선택 유형 집계
    final tally = <String, int>{};
    for (final reply in replies) {
      final qId = reply['question_id'];
      final oId = reply['question_option_id'];

      try {
        final q = kTripDnaQuestions.firstWhere((element) => element.id == qId);
        final opt = q.options.firstWhere((element) => element.id == oId);
        if (opt.dnaType != null) {
          tally[opt.dnaType!] = (tally[opt.dnaType!] ?? 0) + 1;
        }
      } catch (_) {
        // 찾을 수 없는 경우 무시
      }
    }

    var best = 'nature';
    var max = -1;
    tally.forEach((type, count) {
      if (count > max) {
        max = count;
        best = type;
      }
    });

    return {
      'user_id': '00000000-0000-0000-0000-000000000000',
      'main_dna_type': best == 'active' ? 'activity' : best,
      'scores': tally,
    };
  }
}

class ApiTripDnaRepository implements TripDnaRepository {
  const ApiTripDnaRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<TripDnaQuestion>> questions() async {
    final response = await _dio.get('/trip_dna/questions');
    // Envelope 포맷: {code: SUCCESS, status: 200, message: ..., data: [...]}
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((json) => TripDnaQuestion.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> submitReplies(
    List<Map<String, String>> replies,
  ) async {
    final response = await _dio.post(
      '/trip_dna/replies',
      data: {'replies': replies},
    );
    // Envelope 포맷: {code: SUCCESS, status: 201, message: ..., data: {...}}
    final data = response.data['data'] as Map<String, dynamic>;
    final mainDnaType = data['main_dna_type'];
    return {...data, if (mainDnaType == 'active') 'main_dna_type': 'activity'};
  }
}

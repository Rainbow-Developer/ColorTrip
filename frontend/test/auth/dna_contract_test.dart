import 'package:colortrip/core/constants.dart';
import 'package:colortrip/data/models/category_vocabulary.dart';
import 'package:colortrip/data/static/dna_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter recognizes every DNA identifier returned by the backend', () {
    const backendDnaTypes = {
      'nature',
      'food',
      'history',
      'activity',
      'healing',
    };

    expect(kDnaTypes.keys.toSet(), backendDnaTypes);
    for (final id in backendDnaTypes) {
      expect(dnaTypeById(id).id, id);
      expect(questTypeStyles[id], isNotNull);
      expect(questTypeIconColors[id], isNotNull);
    }
  });

  test('legacy active category is normalized to activity', () {
    expect(toAppCategory('active'), 'activity');
    expect(toAppCategory('activity'), 'activity');
    expect(toServerCategory('active'), 'activity');
    expect(toServerCategory('activity'), 'activity');
  });
}

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants.dart';

/// 생년월일 선택 — 연·월·일 3단 휠 바텀시트.
///
/// Material `showDatePicker`는 연도를 고른 뒤 곧바로 일 달력으로 돌아가 월은 좌우 화살표로만
/// 넘길 수 있어, 수십 년 전 날짜를 고르는 생년월일 입력에 손이 많이 갔다(KAN-73 사용자 피드백).
/// 세 휠은 [firstDate]~[lastDate] 범위에서 **유효한 값만** 노출한다 — 선택 후 조용히 값을
/// 클램프하지 않고, 애초에 고를 수 없게 한다.
Future<DateTime?> showBirthDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  assert(!firstDate.isAfter(lastDate), 'firstDate는 lastDate보다 늦을 수 없다');
  return showModalBottomSheet<DateTime>(
    context: context,
    // 기본 최대 높이(화면의 9/16)로는 작은 화면에서 휠+버튼이 잘린다.
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _BirthDateWheels(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _BirthDateWheels extends StatefulWidget {
  const _BirthDateWheels({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_BirthDateWheels> createState() => _BirthDateWheelsState();
}

class _BirthDateWheelsState extends State<_BirthDateWheels> {
  static const _itemExtent = 40.0;
  static const _wheelHeight = 200.0;

  late int _year;
  late int _month;
  late int _day;

  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  /// 범위 보정 중 여부 — `jumpToItem`은 리빌드 전에 `onSelectedItemChanged`를 동기로
  /// 다시 부르고, 그 콜백은 **보정 전 목록**을 참조한다. 그대로 두면 연도를 한 칸 옮겼을 때
  /// 월·일이 엉뚱한 값으로 연쇄 이동한다(firstDate가 1월 1일이 아닐 때 재현).
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final initial = _clamp(widget.initialDate);
    _year = initial.year;
    _month = initial.month;
    _day = initial.day;
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_year),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _months.indexOf(_month),
    );
    _dayController = FixedExtentScrollController(
      initialItem: _days.indexOf(_day),
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime value) {
    if (value.isBefore(widget.firstDate)) return widget.firstDate;
    if (value.isAfter(widget.lastDate)) return widget.lastDate;
    return value;
  }

  List<int> get _years => [
    for (var year = widget.firstDate.year; year <= widget.lastDate.year; year++)
      year,
  ];

  List<int> get _months {
    final first = _year == widget.firstDate.year ? widget.firstDate.month : 1;
    final last = _year == widget.lastDate.year ? widget.lastDate.month : 12;
    return [for (var month = first; month <= last; month++) month];
  }

  List<int> get _days {
    final first =
        _year == widget.firstDate.year && _month == widget.firstDate.month
        ? widget.firstDate.day
        : 1;
    final last =
        _year == widget.lastDate.year && _month == widget.lastDate.month
        ? widget.lastDate.day
        : DateTime(_year, _month + 1, 0).day; // 다음 달 0일 = 이번 달 말일
    return [for (var day = first; day <= last; day++) day];
  }

  /// 연도가 바뀌면 월·일의 유효 범위가 모두 달라진다. 벗어난 값은 가장 가까운 유효 값으로
  /// 옮기고 휠 위치도 함께 맞춘다(휠에 보이는 값과 선택 값이 어긋나지 않게).
  void _syncForYearChange() {
    _syncing = true;
    final months = _months;
    if (!months.contains(_month)) {
      _month = _month < months.first ? months.first : months.last;
    }
    _monthController.jumpToItem(months.indexOf(_month));
    _syncDay();
    _syncing = false;
  }

  /// 월이 바뀌면 **일 범위만** 달라진다(월 범위는 연도에만 의존한다).
  ///
  /// 여기서 월 컨트롤러를 건드리면 안 된다 — 휠을 굴리는 동안 아이템마다
  /// `onSelectedItemChanged`가 불리는데 그때마다 `jumpToItem`으로 되돌리면 관성이 끊겨
  /// **한 칸씩만 움직인다**(KAN-89 사용자 보고). 연·일 휠에 같은 증상이 없던 이유도
  /// 그쪽은 자기 컨트롤러를 되돌리지 않기 때문이다.
  void _syncForMonthChange() {
    _syncing = true;
    _syncDay();
    _syncing = false;
  }

  void _syncDay() {
    final days = _days;
    if (!days.contains(_day)) {
      _day = _day < days.first ? days.first : days.last;
    }
    _dayController.jumpToItem(days.indexOf(_day));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '생년월일을 선택해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              // 화면이 낮으면 휠을 줄여 버튼이 잘리지 않게 한다.
              height: math.min(
                _wheelHeight,
                MediaQuery.sizeOf(context).height * 0.3,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _wheel(
                      controller: _yearController,
                      values: _years,
                      suffix: '년',
                      onSelected: (value) => setState(() {
                        _year = value;
                        _syncForYearChange();
                      }),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _wheel(
                      controller: _monthController,
                      values: _months,
                      suffix: '월',
                      onSelected: (value) => setState(() {
                        _month = value;
                        _syncForMonthChange();
                      }),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _wheel(
                      controller: _dayController,
                      values: _days,
                      suffix: '일',
                      onSelected: (value) => setState(() => _day = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, DateTime(_year, _month, _day)),
              child: const Text('선택 완료'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required List<int> values,
    required String suffix,
    required ValueChanged<int> onSelected,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: _itemExtent,
      childCount: values.length,
      // 선택 강조는 **글자가 비쳐야** 한다 — CupertinoPicker는 이 오버레이를 아이템 위에
      // 겹쳐 그리므로, 불투명하게 채우면 선택된 값이 통째로 가려진다(KAN-89 사용자 보고).
      selectionOverlay: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
          ),
        ),
      ),
      // 휠이 멈춘 위치가 곧 선택 값이다(별도 확인 탭 없이 "선택 완료"로 확정).
      // 범위 보정이 유발한 콜백은 낡은 목록을 참조하므로 무시한다([_syncing]).
      onSelectedItemChanged: (index) {
        if (_syncing || index >= values.length) return;
        onSelected(values[index]);
      },
      itemBuilder: (context, index) => Center(
        child: Text(
          '${values[index]}$suffix',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';

import '../../state/progress_state.dart';
import '../constants.dart';

/// 여행 이름·기간 입력 시트 — 여행 시작과 여행 정보 수정에서 같은 입력 경험을 공유한다.
class TripInfoSheet extends StatefulWidget {
  const TripInfoSheet({
    super.key,
    required this.initialName,
    this.initialRange,
    this.title = '여행 정보를 입력해주세요',
    this.submitLabel = '저장하기',
  });

  final String initialName;
  final DateTimeRange? initialRange;
  final String title;
  final String submitLabel;

  @override
  State<TripInfoSheet> createState() => _TripInfoSheetState();
}

class _TripInfoSheetState extends State<TripInfoSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late DateTimeRange? _range = widget.initialRange;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialStart = _range?.start;
    final firstDate = initialStart != null && initialStart.isBefore(today)
        ? DateTime(initialStart.year, initialStart.month, initialStart.day)
        : today;
    List<DateTime?> tempRange = _range != null
        ? [_range!.start, _range!.end]
        : [];

    if (!mounted) return;
    final picked = await showModalBottomSheet<DateTimeRange>(
      context: context,
      // 셸 탭 화면에서 열려도 떠 있는 하단탭 위에 그려지도록 루트 내비게이터에 띄운다.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isValid =
                tempRange.length == 2 &&
                tempRange[0] != null &&
                tempRange[1] != null;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '여행 기간을 선택해주세요',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    CalendarDatePicker2(
                      config: CalendarDatePicker2Config(
                        calendarType: CalendarDatePicker2Type.range,
                        firstDate: firstDate,
                        lastDate: DateTime(now.year + 2, now.month, now.day),
                        selectedDayHighlightColor: AppColors.primaryDark,
                      ),
                      value: tempRange,
                      onValueChanged: (dates) {
                        setSheetState(() {
                          tempRange = dates;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: isValid
                          ? () {
                              Navigator.pop(
                                context,
                                DateTimeRange(
                                  start: tempRange[0]!,
                                  end: tempRange[1]!,
                                ),
                              );
                            }
                          : null,
                      child: const Text('선택 완료'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  InputDecoration _fieldDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.formFieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.formFieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final canSubmit = _nameController.text.trim().isNotEmpty && range != null;

    return SafeArea(
      // 시트는 화면 맨 아래까지 내려오므로 제출 버튼이 시스템 내비게이션 바에
      // 가리지 않게 하단 안전 영역을 확보한다(targetSdk 36 edge-to-edge).
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '여행 이름',
                style: TextStyle(fontSize: 12, color: AppColors.formLabel),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                maxLength: 30,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(
                  hintText: '예) 단양 여행',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 12),
              const Text(
                '여행 날짜',
                style: TextStyle(fontSize: 12, color: AppColors.formLabel),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickRange,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: _fieldDecoration(
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                  child: Text(
                    range == null
                        ? '시작일 ~ 종료일 선택'
                        : TripInfo.formatPeriod(range.start, range.end),
                    style: TextStyle(
                      fontSize: 14,
                      color: range == null
                          ? AppColors.formPlaceholder
                          : AppColors.textStrong,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: canSubmit
                    ? () => Navigator.pop(
                        context,
                        TripInfo(
                          name: _nameController.text.trim(),
                          startDate: range.start,
                          endDate: range.end,
                        ),
                      )
                    : null,
                child: Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<TripInfo?> showTripInfoSheet({
  required BuildContext context,
  required String initialName,
  DateTimeRange? initialRange,
  required String title,
  required String submitLabel,
}) {
  return showModalBottomSheet<TripInfo>(
    context: context,
    // 여행 탭(셸 안)에서 열면 기본값(false)으로는 브랜치 내비게이터에 떠서
    // 떠 있는 하단탭이 저장 버튼을 가린다(100-bottom-nav-redesign) — 루트에 띄운다.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => TripInfoSheet(
      initialName: initialName,
      initialRange: initialRange,
      title: title,
      submitLabel: submitLabel,
    ),
  );
}

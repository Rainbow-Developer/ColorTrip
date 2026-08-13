import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/widgets/app_form_field.dart';
import '../../data/models/auth_models.dart';
import '../../state/auth_controller.dart';
import '../../state/progress_notifier.dart';
import 'profile_validation.dart';

/// 회원가입 — Figma 스펙(2026-07-08 공유) 반영: 닉네임(카카오 프로필 프리필 가정)
/// + 이름·생년월일·이메일(빈 값, placeholder) + 필수/선택 약관 동의.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _birthdateController;
  late final TextEditingController _emailController;

  // 필수 약관은 사용자가 실제로 체크해야만 진행 가능하다 — 사전 체크는 컴플라이언스 리스크
  // (CodeRabbit 리뷰 반영, 이전엔 true로 사전 체크되어 있었음).
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _birthdateController = TextEditingController(
      text: user?.birthDate == null ? '' : _date(user!.birthDate!),
    );
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _birthdateController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: _confirmExit,
          ),
          title: const Text('회원가입'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '기본 정보를 입력해주세요',
                  style: TextStyle(color: AppColors.formLabel, fontSize: 14),
                ),
                const SizedBox(height: 16),
                const _StepProgress(totalSteps: 3, currentStep: 2),
                const SizedBox(height: 20),
                AppFormField(
                  label: '닉네임',
                  controller: _nicknameController,
                  hint: '닉네임을 입력해주세요',
                  enabled: !auth.isBusy,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                if (_errors['nickname'] case final error?) _FieldError(error),
                const SizedBox(height: 14),
                AppFormField(
                  label: '생년월일',
                  controller: _birthdateController,
                  hint: '2000-01-01',
                  enabled: !auth.isBusy,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_errors['birthDate'] case final error?) _FieldError(error),
                const SizedBox(height: 14),
                AppFormField(
                  label: '이메일',
                  controller: _emailController,
                  hint: 'example@email.com',
                  enabled: !auth.isBusy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
                if (_errors['email'] case final error?) _FieldError(error),
                const SizedBox(height: 20),
                _AgreementCheckbox(
                  label: '[필수] 이용약관 동의',
                  value: _agreeTerms,
                  onChanged: auth.isBusy
                      ? null
                      : (v) => setState(() => _agreeTerms = v),
                ),
                const SizedBox(height: 8),
                _AgreementCheckbox(
                  label: '[필수] 개인정보 처리방침',
                  value: _agreePrivacy,
                  onChanged: auth.isBusy
                      ? null
                      : (v) => setState(() => _agreePrivacy = v),
                  onViewDetails: _openPrivacyPolicy,
                ),
                const SizedBox(height: 8),
                _AgreementCheckbox(
                  label: '[선택] 마케팅 수신 동의',
                  value: _agreeMarketing,
                  onChanged: auth.isBusy
                      ? null
                      : (v) => setState(() => _agreeMarketing = v),
                ),
                if (auth.errorMessage case final error?) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_agreeTerms && _agreePrivacy && !auth.isBusy)
                      ? _submit
                      : null,
                  child: auth.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('다음'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final validation = validateOnboardingProfile(
      nickname: _nicknameController.text,
      email: _emailController.text,
      birthDate: _birthdateController.text,
      today: DateTime.now(),
    );
    if (validation.errors.isNotEmpty) {
      setState(() => _errors = validation.errors);
      return;
    }
    setState(() => _errors = const {});
    final nickname = _nicknameController.text.trim();
    final success = await ref
        .read(authControllerProvider.notifier)
        .submitOnboardingProfile(
          OnboardingProfileInput(
            nickname: nickname,
            email: _emailController.text.trim(),
            birthDate: validation.birthDate!,
            termsAgreed: _agreeTerms,
            privacyAgreed: _agreePrivacy,
            marketingAgreed: _agreeMarketing,
          ),
        );
    if (!mounted) return;
    if (success) {
      ref.read(progressProvider.notifier).setNickname(nickname);
      context.go('/trip-dna');
    }
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final firstDate = minimumBirthDate(today);
    final parsed = DateTime.tryParse(_birthdateController.text);
    final initial =
        parsed != null && !parsed.isBefore(firstDate) && !parsed.isAfter(today)
        ? parsed
        : DateTime(today.year - 26, today.month, today.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: today,
    );
    if (selected == null || !mounted) return;
    setState(() => _birthdateController.text = _date(selected));
  }

  Future<void> _confirmExit() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원가입을 중단할까요?'),
        content: const Text('입력한 내용은 저장되지 않으며 로그아웃됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    ref.read(progressProvider.notifier).reset();
    context.go('/splash');
  }

  /// 개인정보처리방침 페이지를 외부 브라우저로 연다. 새 dart-define 없이 기존
  /// 필수 빌드값인 apiBaseUrl(예: https://host/api/v1)의 origin에 /privacy를
  /// 붙여 URL을 계산한다 (075-privacy-policy-page).
  Future<void> _openPrivacyPolicy() async {
    final apiBaseUrl = ref.read(appConfigProvider).apiBaseUrl;
    final origin = Uri.parse(apiBaseUrl);
    final privacyUrl = origin.replace(path: '/privacy', query: '');
    final opened = await launchUrl(
      privacyUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('개인정보처리방침 페이지를 열 수 없어요.')));
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.danger, fontSize: 12),
    ),
  );
}

/// 온보딩 단계 표시 막대(3칸 중 N칸 채움). 정확한 단계 정의는 Figma에 명시되지 않아
/// 회원가입 화면 기준 2/3로 고정했다 — 실제 단계 수/의미가 확정되면 조정 필요.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.totalSteps, required this.currentStep});

  final int totalSteps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < totalSteps; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 4),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < currentStep
                      ? AppColors.primaryDark
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AgreementCheckbox extends StatefulWidget {
  const _AgreementCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onViewDetails,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 지정하면 라벨 옆에 "보기" 링크를 표시해 약관 본문을 별도로 열람할 수 있게
  /// 한다. 체크박스 토글과는 별개의 탭 영역이라 서로 간섭하지 않는다.
  final VoidCallback? onViewDetails;

  @override
  State<_AgreementCheckbox> createState() => _AgreementCheckboxState();
}

class _AgreementCheckboxState extends State<_AgreementCheckbox> {
  var _showFocus = false;

  @override
  Widget build(BuildContext context) {
    final toggle = widget.onChanged == null
        ? null
        : () => widget.onChanged!(!widget.value);
    final checkboxRow = Semantics(
      container: true,
      label: widget.label,
      checked: widget.value,
      button: true,
      enabled: widget.onChanged != null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: widget.onChanged != null,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              toggle?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        child: InkWell(
          onTap: toggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: widget.value
                      ? AppColors.primaryDark
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: widget.value || _showFocus
                        ? AppColors.primaryDark
                        : AppColors.checkboxBorder,
                  ),
                ),
                child: widget.value
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.onViewDetails == null) return checkboxRow;
    return Row(
      children: [
        checkboxRow,
        const Spacer(),
        InkWell(
          onTap: widget.onViewDetails,
          child: const Text(
            '보기',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryDark,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

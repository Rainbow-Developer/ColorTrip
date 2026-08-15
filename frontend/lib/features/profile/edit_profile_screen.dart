import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/network/dio_client.dart';
import '../../core/widgets/app_form_field.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/birth_date_picker.dart';
import '../../core/widgets/profile_image_picker.dart';
import '../../data/models/auth_models.dart';
import '../../features/onboarding/profile_validation.dart';
import '../../state/auth_controller.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 내 정보 수정 — Figma 스펙(2026-07-08 공유) 반영: 프로필 아이콘, 닉네임/이름/생년월일
/// 필드, 여행 DNA 유형(탭하면 설문 재응시), 아웃라인 스타일 회원 탈퇴 버튼.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _birthdateController;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _birthdateController = TextEditingController(
      text: user?.birthDate == null ? '' : _date(user!.birthDate!),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dnaType = ref.watch(progressProvider).dnaType ?? 'nature';
    final user = ref.watch(currentUserProvider);
    final dna = ref.watch(dnaRepositoryProvider).byId(user?.dna ?? dnaType);
    final auth = ref.watch(authControllerProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('내 정보 수정'),
        titleSpacing: 0,
        actions: [
          TextButton(
            onPressed: auth.isBusy ? null : _save,
            child: auth.isBusy ? const Text('저장 중') : const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ProfileImagePicker(
                imageUrl: ref.watch(resolveUploadUrlProvider)(
                  user?.profileImage,
                ),
                isBusy: auth.isBusy,
                size: 80,
                // notifier를 build 시점에 잡아 콜백에 넘긴다. 콜백 안에서 `ref.read`를
                // 하면, 카메라·갤러리가 떠 있는 동안 Android가 Activity를 재생성했을 때
                // 이 화면이 unmount돼 "Using ref ... unmounted" 예외로 업로드가 조용히
                // 사라진다. notifier 자체는 ProviderContainer가 들고 있어 안전하다.
                onPicked: (picked) => authNotifier.uploadProfileImage(
                  picked.bytes,
                  mimeType: picked.mimeType,
                ),
                onRemoved: authNotifier.removeProfileImage,
              ),
            ),
            const SizedBox(height: 24),
            AppFormField(
              label: '닉네임',
              controller: _nicknameController,
              hint: '닉네임을 입력해주세요',
              enabled: !auth.isBusy,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            if (_errors['nickname'] case final error?) _ErrorText(error),
            const SizedBox(height: 14),
            AppFormField(
              label: '생년월일',
              controller: _birthdateController,
              hint: '2000-01-01',
              enabled: !auth.isBusy,
              readOnly: true,
              onTap: _pickBirthDate,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              onChanged: (_) => setState(() {}),
            ),
            if (_errors['birthDate'] case final error?) _ErrorText(error),
            const SizedBox(height: 14),
            // 이메일 필드는 수집 폐지로 제거했다. DNA 재검사 이동은 dev(#73)에서
            // 활성화된 동작이라 그대로 살린다.
            _DnaTypeField(
              label: dna.name,
              onTap: () => context.push('/trip-dna'),
            ),
            if (auth.errorMessage case final error?) ...[
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => _confirmWithdraw(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: Color(0xFFFFBFBF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('회원 탈퇴'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final validation = validateOnboardingProfile(
      nickname: _nicknameController.text,
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
        .updateProfile(
          // 생년월일이 비어 있으면 null → 요청에서 생략되어 서버 값이 유지된다.
          // (지우기는 지원하지 않는다 — 서버가 birth_date: null을 거부한다)
          ProfileUpdateInput(
            nickname: nickname,
            birthDate: validation.birthDate,
          ),
        );
    if (!mounted) return;
    if (success) {
      ref.read(progressProvider.notifier).setNickname(nickname);
      showAppToast(context, '변경사항이 저장되었어요');
      // 저장하면 수정 화면에 남지 않고 마이로 돌아간다.
      //
      // `pop()`만 쓰면 화면에 남는 경우가 있다. 저장 성공이 auth 상태를 바꾸고, 그게
      // refreshListenable을 통해 GoRouter를 재평가시켜 `/profile/edit`이 스택 없는
      // 단독 경로가 되기 때문이다(이때 canPop()은 false). 마이 탭 경로로 직접 이동해
      // 스택 상태와 무관하게 같은 결과를 보장한다 — 탭 경로는 '/profile'이 아니라 '/my'다.
      context.go('/my');
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
    final selected = await showBirthDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: today,
    );
    if (selected == null || !mounted) return;
    setState(() => _birthdateController.text = _date(selected));
  }

  void _confirmWithdraw(BuildContext context) {
    final screenContext = context;
    final controller = ref.read(authControllerProvider.notifier);
    final progress = ref.read(progressProvider.notifier);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 탈퇴하시겠어요?'),
        content: const Text(
          '계정 개인정보는 즉시 익명화되며 복구할 수 없습니다. 여행 기록은 익명 상태로 보존됩니다.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              context.pop();
              await controller.withdraw();
              if (!screenContext.mounted) return;
              if (ref.read(authControllerProvider).status ==
                  AuthStatus.unauthenticated) {
                progress.reset();
                screenContext.go('/splash');
              }
            },
            child: const Text(
              '탈퇴하기',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _DnaTypeField extends StatelessWidget {
  const _DnaTypeField({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '여행 DNA 유형',
          style: TextStyle(color: AppColors.formLabel, fontSize: 13),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryDark, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF222222),
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      '다시하기',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '›',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

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

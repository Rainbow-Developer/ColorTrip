import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_form_field.dart';
import '../../core/widgets/app_toast.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

/// 내 정보 수정 — Figma 스펙(2026-07-08 공유) 반영: 프로필 아이콘, 닉네임/이름/생년월일/이메일(변경불가)
/// 필드, 여행 DNA 유형(탭하면 설문 재응시), 아웃라인 스타일 회원 탈퇴 버튼.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _nicknameController = TextEditingController(
    text: ref.read(progressProvider).nickname ?? kDefaultNickname,
  );
  final _nameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _emailController = TextEditingController(
    text: 'example@email.com (변경불가)',
  );

  @override
  void dispose() {
    _nicknameController.dispose();
    _nameController.dispose();
    _birthdateController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dnaType = ref.watch(progressProvider).dnaType ?? 'nature';
    final dna = ref.watch(dnaRepositoryProvider).byId(dnaType);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('내 정보 수정'),
        actions: [
          TextButton(
            onPressed: () {
              final nickname = _nicknameController.text.trim();
              if (nickname.isNotEmpty) {
                ref.read(progressProvider.notifier).setNickname(nickname);
              }
              showAppToast(context, '변경사항이 저장되었어요');
              context.pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.imagePlaceholderBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.checkboxBorder),
                ),
                alignment: Alignment.center,
                child: const Text('👤', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 24),
            AppFormField(
              label: '닉네임',
              controller: _nicknameController,
              hint: '닉네임을 입력해주세요',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: '이름',
              controller: _nameController,
              hint: '홍길동',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: '생년월일',
              controller: _birthdateController,
              hint: '1990.01.01',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: '이메일',
              controller: _emailController,
              hint: 'example@email.com',
              enabled: false,
            ),
            const SizedBox(height: 14),
            _DnaTypeField(
              label: dna.name,
              onTap: () => context.push('/survey'),
            ),
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

  void _confirmWithdraw(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 탈퇴하시겠어요?'),
        content: const Text('탈퇴 시 모든 퀘스트 기록과 지도 데이터가 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ref.read(progressProvider.notifier).reset();
              context.pop();
              context.go('/splash');
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
}

class _DnaTypeField extends StatelessWidget {
  const _DnaTypeField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

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
              color: AppColors.formFieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.formFieldBorder),
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
                const Text(
                  '›',
                  style: TextStyle(
                    color: AppColors.timelineDotGrey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

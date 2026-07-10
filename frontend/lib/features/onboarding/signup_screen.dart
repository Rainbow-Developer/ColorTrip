import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_form_field.dart';
import '../../state/progress_notifier.dart';

/// 회원가입 — Figma 스펙(2026-07-08 공유) 반영: 닉네임(카카오 프로필 프리필 가정)
/// + 이름·생년월일·이메일(빈 값, placeholder) + 필수/선택 약관 동의.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  // 카카오 로그인이 실제 연동되기 전까지는 프로필 닉네임을 가져올 수 없어 빈 값으로 시작한다.
  // 하드코딩된 예시값을 넣으면 사용자가 수정하지 않고 넘어갈 때 그대로 저장되는 문제가 있었다
  // (CodeRabbit 리뷰 반영).
  final _nicknameController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _emailController = TextEditingController();

  // 필수 약관은 사용자가 실제로 체크해야만 진행 가능하다 — 사전 체크는 컴플라이언스 리스크
  // (CodeRabbit 리뷰 반영, 이전엔 true로 사전 체크되어 있었음).
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.go('/splash'),
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
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppFormField(
                label: '이름',
                controller: _nameController,
                hint: '최동인',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppFormField(
                label: '생년월일',
                controller: _birthdateController,
                hint: '1909.01.01',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppFormField(
                label: '이메일',
                controller: _emailController,
                hint: 'example@email.com',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _AgreementCheckbox(
                label: '[필수] 이용약관 동의',
                value: _agreeTerms,
                onChanged: (v) => setState(() => _agreeTerms = v),
              ),
              const SizedBox(height: 8),
              _AgreementCheckbox(
                label: '[필수] 개인정보 처리방침',
                value: _agreePrivacy,
                onChanged: (v) => setState(() => _agreePrivacy = v),
              ),
              const SizedBox(height: 8),
              _AgreementCheckbox(
                label: '[선택] 마케팅 수신 동의',
                value: _agreeMarketing,
                onChanged: (v) => setState(() => _agreeMarketing = v),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_agreeTerms && _agreePrivacy)
                    ? () {
                        final nickname = _nicknameController.text.trim();
                        if (nickname.isNotEmpty) {
                          ref
                              .read(progressProvider.notifier)
                              .setNickname(nickname);
                        }
                        context.go('/survey');
                      }
                    : null,
                child: const Text('다음'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _AgreementCheckbox extends StatelessWidget {
  const _AgreementCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? AppColors.primaryDark : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: value ? AppColors.primaryDark : AppColors.checkboxBorder,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

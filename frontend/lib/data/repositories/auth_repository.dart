/// 카카오 로그인 인터페이스. 현재는 UI 스텁(항상 성공)이며, 실제 Kakao+JWT 연동은
/// 후속 스펙에서 이 인터페이스의 구현체만 교체한다([plan.md] 의사결정).
abstract class AuthRepository {
  Future<void> loginWithKakao();
}

class StubAuthRepository implements AuthRepository {
  const StubAuthRepository();

  @override
  Future<void> loginWithKakao() async {}
}

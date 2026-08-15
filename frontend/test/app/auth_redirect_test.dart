import 'package:colortrip/app/router.dart';
import 'package:colortrip/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unauthenticated users are redirected to splash', () {
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.unauthenticated),
        '/home',
      ),
      '/splash',
    );
  });

  test('server profile and DNA steps select their matching routes', () {
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.profileRequired),
        '/home',
      ),
      '/signup',
    );
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.tripDnaRequired),
        '/home',
      ),
      '/trip-dna',
    );
  });

  test('authenticated users cannot return to incomplete auth steps', () {
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.authenticated),
        '/signup',
      ),
      '/home',
    );
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.authenticated),
        '/trip-dna',
      ),
      isNull,
    );
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.authenticated),
        '/trip-dna/result',
      ),
      isNull,
    );
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.authenticated),
        '/withdrawal-pending',
      ),
      '/home',
    );
  });

  test('authenticated users can open share deep link routes', () {
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.authenticated),
        '/share/WI135Hbj',
      ),
      isNull,
    );
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.authenticated),
        '/WI135Hbj',
      ),
      isNull,
    );
  });

  test('withdrawal pending state always opens retry route', () {
    expect(
      authRedirect(
        const AuthState(status: AuthStatus.withdrawalPending),
        '/my',
      ),
      '/withdrawal-pending',
    );
  });
}

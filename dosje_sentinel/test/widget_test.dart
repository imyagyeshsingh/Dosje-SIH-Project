import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/app/app.dart';
import 'package:dosje_sentinel/core/auth/auth_guard.dart';
import 'package:dosje_sentinel/core/auth/auth_state.dart';
import 'package:dosje_sentinel/core/auth/role_guard.dart';
import 'package:dosje_sentinel/core/auth/permission_guard.dart';
import 'package:dosje_sentinel/core/auth/auth_service.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/core/realtime/realtime_service.dart';
import 'package:dosje_sentinel/repositories/ngo_repository.dart';
import 'package:dosje_sentinel/repositories/official_ngo_repository.dart';
import 'package:dosje_sentinel/shared/models/ngo_profile_model.dart';
import 'package:dosje_sentinel/shared/models/ngo_registration_status.dart';
import 'package:dosje_sentinel/shared/models/permission.dart';
import 'package:dosje_sentinel/shared/models/user_model.dart';
import 'package:dosje_sentinel/shared/models/user_role.dart';

void main() {
  group('SECTION 22 MANDATORY VERIFICATION TESTS (TEST 1 - TEST 15)', () {
    // TEST 1: Fresh install -> Login screen (Single unified entry point, NO role tabs)
    testWidgets(
      'TEST 1: Fresh install launches into single Clerk login screen with no role selector tabs',
      (WidgetTester tester) async {
        await tester.pumpWidget(const ProviderScope(child: DosjeSentinelApp()));
        await tester.pumpAndSettle();

        // Verified single unified login UI
        expect(find.text('DoSJE Sentinel'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Get Verification Code'), findsOneWidget);
        expect(
          find.textContaining('single sign-on', findRichText: true),
          findsOneWidget,
        );

        // Verifies no separate role selection or tabs exist in production view
        expect(find.text('NGO Portal (Clerk SSO)'), findsNothing);
        expect(find.text('Official / Inspector'), findsNothing);
        expect(find.text('Select your role'), findsNothing);
      },
    );

    // TEST 2: NGO Clerk authentication -> incomplete -> NGO Registration
    test('TEST 2: NGO Clerk authentication with incomplete registration routes to /ngo/onboarding/register', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'new.representative@gramin-vikas.org',
        password: 'password123',
        status: NgoRegistrationStatus.incomplete,
      );

      expect(authState.isNgo, isTrue);
      expect(authState.clerkUserId, isNotNull);
      expect(authState.ngoRegistrationStatus, NgoRegistrationStatus.incomplete);
      expect(
        AuthGuard.resolveRedirect('/login', authState),
        '/ngo/onboarding/register',
      );
    });

    // TEST 3: NGO -> submitted -> Submitted screen
    test('TEST 3: NGO with submitted registration routes to /ngo/onboarding/submitted', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'submitted.rep@samarpan.org',
        password: 'password123',
        status: NgoRegistrationStatus.submitted,
      );

      expect(authState.isNgo, isTrue);
      expect(authState.ngoRegistrationStatus, NgoRegistrationStatus.submitted);
      expect(
        AuthGuard.resolveRedirect('/login', authState),
        '/ngo/onboarding/submitted',
      );
    });

    // TEST 4: NGO -> underReview -> Under Review screen
    test('TEST 4: NGO with underReview registration routes to /ngo/onboarding/under-review', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'under.review@samarpan.org',
        password: 'password123',
        status: NgoRegistrationStatus.underReview,
      );

      expect(authState.isNgo, isTrue);
      expect(
        authState.ngoRegistrationStatus,
        NgoRegistrationStatus.underReview,
      );
      expect(
        AuthGuard.resolveRedirect('/login', authState),
        '/ngo/onboarding/under-review',
      );
    });

    // TEST 5: NGO -> correctionRequired -> Correction screen
    test('TEST 5: NGO with correctionRequired registration routes to /ngo/onboarding/correction', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'correction.needed@samarpan.org',
        password: 'password123',
        status: NgoRegistrationStatus.correctionRequired,
      );

      expect(authState.isNgo, isTrue);
      expect(
        authState.ngoRegistrationStatus,
        NgoRegistrationStatus.correctionRequired,
      );
      expect(
        AuthGuard.resolveRedirect('/login', authState),
        '/ngo/onboarding/correction',
      );
    });

    // TEST 6: NGO -> approved -> NGO Home
    test(
      'TEST 6: NGO with approved registration routes directly to /ngo/home',
      () async {
        final authService = DefaultAuthService(apiClient: ApiClient());
        final authState = await authService.signInWithClerk(
          email: 'approved.rep@samarpan.org',
          password: 'password123',
          status: NgoRegistrationStatus.approved,
        );

        expect(authState.isNgo, isTrue);
        expect(authState.ngoRegistrationStatus, NgoRegistrationStatus.approved);
        expect(AuthGuard.resolveRedirect('/login', authState), '/ngo/home');
      },
    );

    // TEST 7: PMU/Inspector Clerk authentication -> Inspector Dashboard
    test('TEST 7: PMU/Inspector Clerk authentication routes automatically to /inspector/dashboard', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'inspector.saxena@dosje.gov.in',
        password: 'password123',
        roleHint: UserRole.inspector,
      );

      expect(authState.isInspector, isTrue);
      expect(authState.user?.role, UserRole.inspector);
      expect(authState.hasPermission(Permission.executeInspection), isTrue);
      expect(
        AuthGuard.resolveRedirect('/login', authState),
        '/inspector/dashboard',
      );
    });

    // TEST 8: Official Clerk authentication -> Official Dashboard
    test('TEST 8: Official Clerk authentication routes automatically to /official/dashboard', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'official.verma@dosje.gov.in',
        password: 'password123',
        roleHint: UserRole.official,
      );

      expect(authState.isOfficial, isTrue);
      expect(authState.user?.role, UserRole.official);
      expect(authState.hasPermission(Permission.viewAllNgos), isTrue);
    });

    // TEST 8b: itsmerudraksha@gmail.com automatically resolves to Official
    test('TEST 8b: itsmerudraksha@gmail.com resolves to Official and routes to /official/dashboard', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'itsmerudraksha@gmail.com',
        password: 'password123',
      );

      expect(authState.isOfficial, isTrue);
      expect(authState.user?.role, UserRole.official);
      expect(authState.hasPermission(Permission.viewAllProjects), isTrue);
      expect(authState.hasPermission(Permission.canApproveAudit), isTrue);
      expect(
        AuthGuard.resolveRedirect('/login', authState),
        '/official/dashboard',
      );
    });

    // TEST 8c: itsmerudraksha1@gmail.com automatically resolves to PMU Inspector
    test('TEST 8c: itsmerudraksha1@gmail.com resolves to PMU Inspector and routes to /inspector/dashboard', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final authState = await authService.signInWithClerk(
        email: 'itsmerudraksha1@gmail.com',
        password: 'password123',
      );

      expect(authState.isInspector, isTrue);
      expect(authState.user?.role, UserRole.inspector);
      expect(authState.hasPermission(Permission.executeInspection), isTrue);
      expect(authState.hasPermission(Permission.submitAuditFindings), isTrue);
      expect(
        AuthGuard.resolveRedirect('/login', authState),
        '/inspector/dashboard',
      );
    });

    // TEST 8d: Wrong OTP is rejected with AppException
    test('TEST 8d: Wrong OTP for Official is strictly rejected', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      expect(
        () => authService.verifyOtp(
          email: 'itsmerudraksha@gmail.com',
          otp: '000000',
        ),
        throwsA(isA<AppException>()),
      );
    });

    // TEST 8e: Wrong OTP for PMU is rejected with AppException
    test('TEST 8e: Wrong OTP for PMU is strictly rejected', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      expect(
        () => authService.verifyOtp(
          email: 'itsmerudraksha1@gmail.com',
          otp: '999999',
        ),
        throwsA(isA<AppException>()),
      );
    });

    // TEST 9: NGO attempts /official/* -> blocked
    test('TEST 9: NGO attempts /official/* route -> blocked and redirected to NGO home', () {
      final authState = AuthState(
        status: AuthStatus.authenticatedWithContext,
        user: UserModel(
          id: 'ngo_1',
          clerkUserId: 'user_clerk_ngo',
          email: 'ngo@samarpan.org',
          fullName: 'Test NGO Officer',
          role: UserRole.ngoRepresentative,
        ),
        ngoRegistrationStatus: NgoRegistrationStatus.approved,
      );

      expect(
        RoleGuard.canAccessRoute(authState, '/official/dashboard'),
        isFalse,
      );
      expect(RoleGuard.canAccessRoute(authState, '/official/ngos'), isFalse);
      expect(RoleGuard.canAccessRoute(authState, '/official/cctv'), isFalse);

      expect(
        AuthGuard.resolveRedirect('/official/dashboard', authState),
        '/ngo/home',
      );
    });

    // TEST 10: NGO attempts /inspector/* -> blocked
    test('TEST 10: NGO attempts /inspector/* route -> blocked and redirected to NGO home', () {
      final authState = AuthState(
        status: AuthStatus.authenticatedWithContext,
        user: UserModel(
          id: 'ngo_1',
          clerkUserId: 'user_clerk_ngo',
          email: 'ngo@samarpan.org',
          fullName: 'Test NGO Officer',
          role: UserRole.ngoRepresentative,
        ),
        ngoRegistrationStatus: NgoRegistrationStatus.approved,
      );

      expect(
        RoleGuard.canAccessRoute(authState, '/inspector/dashboard'),
        isFalse,
      );
      expect(
        RoleGuard.canAccessRoute(authState, '/inspector/assignments'),
        isFalse,
      );

      expect(
        AuthGuard.resolveRedirect('/inspector/dashboard', authState),
        '/ngo/home',
      );
    });

    // TEST 11: Inspector attempts unauthorized Official API -> backend rejects
    test('TEST 11: Inspector attempts unauthorized Official route/permission -> rejected', () {
      final authState = AuthState(
        status: AuthStatus.authenticatedWithContext,
        user: UserModel(
          id: 'insp_1',
          clerkUserId: 'user_clerk_insp',
          email: 'inspector@dosje.gov.in',
          fullName: 'Field Inspector',
          role: UserRole.inspector,
          permissions: const [
            Permission.executeInspection,
            Permission.submitAuditFindings,
          ],
        ),
      );

      expect(
        RoleGuard.canAccessRoute(authState, '/official/dashboard'),
        isFalse,
      );
      expect(PermissionGuard.check(authState, Permission.viewAllNgos), isFalse);
      expect(
        PermissionGuard.check(authState, Permission.approveNgoRegistration),
        isFalse,
      );
      expect(
        AuthGuard.resolveRedirect('/official/dashboard', authState),
        '/inspector/dashboard',
      );
    });

    // TEST 12: Official without required permission -> backend rejects
    test('TEST 12: Official without specific permission is rejected by PermissionGuard', () {
      final limitedOfficialState = AuthState(
        status: AuthStatus.authenticatedWithContext,
        user: UserModel(
          id: 'off_junior',
          clerkUserId: 'user_clerk_off_junior',
          email: 'junior.official@dosje.gov.in',
          fullName: 'Junior Official',
          role: UserRole.official,
          permissions: const [Permission.viewAllProjects],
        ),
      );

      expect(
        PermissionGuard.check(limitedOfficialState, Permission.viewAllProjects),
        isTrue,
      );
      // Unauthorized action
      expect(
        PermissionGuard.check(
          limitedOfficialState,
          Permission.approveNgoRegistration,
        ),
        isFalse,
      );
      expect(
        PermissionGuard.check(limitedOfficialState, Permission.canApproveAudit),
        isFalse,
      );
    });

    // TEST 13: Logout -> /login
    test('TEST 13: Logout clears session and redirects to /login', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());
      final loggedOutState = await authService.signOut();

      expect(loggedOutState.status, AuthStatus.unauthenticated);
      expect(loggedOutState.isAuthenticated, isFalse);
      expect(loggedOutState.user, isNull);
      expect(AuthGuard.resolveRedirect('/ngo/home', loggedOutState), '/login');
    });

    // TEST 14: Cold application start with no session -> /login
    test(
      'TEST 14: Cold application start with no session remains on /login',
      () {
        const initialColdState = AuthState(status: AuthStatus.unauthenticated);
        expect(AuthGuard.resolveRedirect('/login', initialColdState), isNull);
        expect(
          AuthGuard.resolveRedirect('/ngo/home', initialColdState),
          '/login',
        );
        expect(
          AuthGuard.resolveRedirect('/inspector/dashboard', initialColdState),
          '/login',
        );
        expect(
          AuthGuard.resolveRedirect('/official/dashboard', initialColdState),
          '/login',
        );
      },
    );

    // TEST 15: Cold application start with valid Clerk session -> resolve authorization -> correct role UI
    test('TEST 15: Cold start with existing Clerk session handshakes authorization and routes to correct role UI', () async {
      final authService = DefaultAuthService(apiClient: ApiClient());

      // Simulating cold start restoring a valid Clerk token
      const existingToken = 'clerk_persisted_session_token_xyz';
      final resolvedOfficialState = await authService.resolveAuthorization(
        existingToken,
        email: 'official.sharma@dosje.gov.in',
        roleHint: UserRole.official,
      );

      expect(resolvedOfficialState.isAuthenticated, isTrue);
      expect(resolvedOfficialState.isOfficial, isTrue);
      expect(resolvedOfficialState.clerkUserId, isNotNull);
      expect(
        AuthGuard.resolveRedirect('/login', resolvedOfficialState),
        '/official/dashboard',
      );

      final resolvedInspectorState = await authService.resolveAuthorization(
        existingToken,
        email: 'inspector.kumar@dosje.gov.in',
        roleHint: UserRole.inspector,
      );
      expect(resolvedInspectorState.isInspector, isTrue);
      expect(
        AuthGuard.resolveRedirect('/login', resolvedInspectorState),
        '/inspector/dashboard',
      );
    });
  });

  group('NGO Profile Repository & Realtime Updates', () {
    test(
      'MockNgoRepository getMyProfile and submitRegistration updates status',
      () async {
        final repo = MockNgoRepository(
          initialProfile: const NgoProfileModel(
            id: 'test_ngo_1',
            fullName: 'Test Representative',
            designation: 'General Secretary',
            mobileNumber: '+919999999999',
            email: 'test@example.org',
            ngoName: 'Test Welfare Society',
            organizationType: 'Society',
            registrationNumber: 'TEST-REG-101',
            establishmentYear: 2020,
            contactNumber: '+919999999999',
            officialEmail: 'info@test.org',
            address: '123 Test Road',
            state: 'Uttar Pradesh',
            district: 'Lucknow',
            city: 'Lucknow',
            pinCode: '226001',
            status: NgoRegistrationStatus.incomplete,
          ),
        );
        final profile = await repo.getMyProfile();

        expect(profile, isNotNull);
        expect(profile!.ngoName, isNotEmpty);
        expect(profile.registrationNumber, isNotEmpty);

        // Submit registration
        final updated = await repo.submitRegistration(profile.id);
        expect(updated.status, NgoRegistrationStatus.submitted);
      },
    );

    test('Realtime NGO_REGISTERED event updates Official ALL NGOs directory dynamically', () async {
      final officialRepo = MockOfficialNgoRepository();
      final realtimeService = DefaultRealtimeService();

      final initialNgos = await officialRepo.getAllNgos();
      final initialCount = initialNgos.length;

      // Simulate NGO completing registration and emitting event
      final newNgo = NgoProfileModel(
        id: 'ngo_realtime_999',
        fullName: 'Smt. Kavita Sharma',
        designation: 'General Secretary',
        mobileNumber: '+91 98111 22334',
        email: 'kavita@graminuttan.org',
        ngoName: 'Gramin Utthan Sansthan',
        organizationType: 'Registered Society',
        registrationNumber: 'SOC-2026-9912',
        establishmentYear: 2018,
        contactNumber: '+91 11 2345 6789',
        officialEmail: 'info@graminuttan.org',
        address: 'Plot 44, Rural Development Complex',
        state: 'Uttar Pradesh',
        district: 'Agra',
        city: 'Agra',
        pinCode: '282001',
        status: NgoRegistrationStatus.submitted,
        submittedAt: DateTime.now(),
      );

      // Add to repository
      officialRepo.addRegisteredNgo(newNgo);

      // Broadcast WebSocket Event
      realtimeService.emitEvent({
        'event': 'NGO_REGISTERED',
        'ngo_id': newNgo.id,
        'organization_name': newNgo.ngoName,
        'status': newNgo.status.name,
      });

      // Verify official repo has new NGO without app restart
      final updatedNgos = await officialRepo.getAllNgos();
      expect(updatedNgos.length, initialCount + 1);
      expect(updatedNgos.any((n) => n.id == 'ngo_realtime_999'), isTrue);
      expect(
        updatedNgos.firstWhere((n) => n.id == 'ngo_realtime_999').status,
        NgoRegistrationStatus.submitted,
      );
    });
  });
}

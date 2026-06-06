import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kairo_app/features/auth/views/signin_view.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.test',
    );
  });

  testWidgets('Sign in screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignInView()),
    );

    expect(find.text('Iniciar Sesión'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Bienvenido de vuelta a nuestra comunidad'), findsOneWidget);
  });
}

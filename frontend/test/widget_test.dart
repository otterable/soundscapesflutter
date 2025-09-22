import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ermine_soundscapes/screens/dashboard_screen.dart';
import 'package:ermine_soundscapes/api_service.dart';

class FakeApiService extends ApiService {
  FakeApiService() : super(baseUrl: "");

  @override
  Future<List<SoundCategory>> fetchCategories() async {
    return [
      SoundCategory(
        name: 'Beach',
        files: [
          SoundFile(
            name: 'waves.mp3',
            url: '/static/soundscapes/Beach/waves.mp3',
          ),
        ],
      ),
      SoundCategory(
        name: 'Forest',
        files: [
          SoundFile(
            name: 'leaves.wav',
            url: '/static/soundscapes/Forest/leaves.wav',
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<SoundFile>> fetchAllFiles() async {
    final cats = await fetchCategories();
    return cats.expand((c) => c.files).toList();
  }
}

void main() {
  testWidgets('Dashboard renders category buttons', (WidgetTester tester) async {
    final api = FakeApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(api: api),
      ),
    );

    // Shows loader first.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Resolve futures and build UI.
    await tester.pumpAndSettle();

    // AppBar title is present.
    expect(find.text('Ermine Soundscapes'), findsOneWidget);

    // "All" + the two fake categories.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Beach'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
  });
}

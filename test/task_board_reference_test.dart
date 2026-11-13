import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/features/tasks/screens/task_screen.dart';
import 'workspace_style_test.dart';

class TaskReferenceAdapter extends WorkspaceAdapter {
  final actions = <String>[];
  bool awaitingReview = false;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    if (options.method == 'POST' && options.path.contains('/tasks/')) {
      actions.add(options.path);
      return ResponseBody.fromString('{"message":"Updated"}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
    }
    if (options.path.endsWith('/tasks')) {
      queries.add(Map.of(options.queryParameters));
      final today = DateTime.now().toIso8601String().split('T').first;
      final names = [
        'Perbaikan Error Modul Logistic Out Pada Halaman Purchase Orders Dan Comments',
        'Review & Finalisasi Materi Middle Management',
        '@Rosyad LDAP Mohon Selesai Dicek Apakah Sudah Masuk Tugas Ini...',
        'Pengujian Pembuatan Workhub Hari Ini',
        'Tolong Ingatkan Print Ini Ya Nanti Jam 11',
      ];
      final body = {
        'data': [
          for (var i = 0; i < names.length; i++)
            {
              'id': i + 1,
              'title': names[i],
              'status': awaitingReview && i == 0
                  ? 'pending_review'
                  : i < 2
                      ? 'in_progress'
                      : 'open',
              'progress_percent': awaitingReview && i == 0
                  ? 100
                  : i < 2
                      ? 50
                      : 0,
              'due_date': today,
              'priority': i == 0 ? 'high' : 'medium',
              'row_action': awaitingReview && i == 0 ? null : 'complete',
              'attachment_count': i == 0
                  ? 3
                  : i == 2 || i == 4
                      ? 1
                      : 0,
              'assignees': [
                {'full_name': i == 2 ? 'Rosyad' : 'Budi Santosa'}
              ],
            }
        ],
        'meta': {'total': 5, 'current_page': 1, 'last_page': 1}
      };
      return ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
    }
    return super.fetch(options, stream, cancel);
  }
}

void main() {
  testWidgets('date tabs and View All clear obsolete date bounds',
      (tester) async {
    final adapter = TaskReferenceAdapter();
    await tester.pumpWidget(workspaceApp(const TaskScreen(), adapter: adapter));
    await tester.pumpAndSettle();
    final today = DateTime.now().toIso8601String().split('T').first;
    expect(adapter.queries.last['from'], today);
    await tester.tap(find.text('Overdue'));
    await tester.pumpAndSettle();
    expect(adapter.queries.last['status'], 'overdue');
    expect(adapter.queries.last.containsKey('from'), isFalse);
    expect(adapter.queries.last.containsKey('to'), isFalse);
    await tester.tap(find.text('This Week'));
    await tester.pumpAndSettle();
    expect(adapter.queries.last.containsKey('from'), isTrue);
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(adapter.queries.last['status'], 'all');
    expect(adapter.queries.last.containsKey('from'), isFalse);
    expect(adapter.queries.last.containsKey('to'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task checkbox uses the existing completion endpoint',
      (tester) async {
    final adapter = TaskReferenceAdapter();
    await tester.pumpWidget(workspaceApp(const TaskScreen(), adapter: adapter));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
        adapter.actions
            .where((path) => path.endsWith('/tasks/1/complete'))
            .length,
        1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a full-progress task awaiting review stays active',
      (tester) async {
    await tester.pumpWidget(workspaceApp(const TaskScreen(),
        adapter: TaskReferenceAdapter()..awaitingReview = true));
    await tester.pumpAndSettle();
    expect(find.text('Active Tasks (5)'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    final box = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(box.value, isFalse);
    expect(box.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reference rows preserve metadata at narrow widths and larger text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(workspaceApp(const TaskScreen(),
        adapter: TaskReferenceAdapter(), scale: 1.4));
    await tester.pumpAndSettle();
    expect(find.text('Active Tasks (5)'), findsOneWidget);
    expect(find.text('High'), findsWidgets);
    expect(find.text('3 attachments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

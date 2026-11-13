import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/realtime/reverb_service.dart';
import 'package:workhub_mobile/core/theme/orbit_theme.dart';
import 'package:workhub_mobile/core/widgets/orbit_workspace.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/inbox/models/inbox_item_model.dart';
import 'package:workhub_mobile/features/inbox/screens/inbox_screen.dart';
import 'package:workhub_mobile/features/projects/screens/projects_screen.dart';
import 'package:workhub_mobile/features/tasks/screens/task_screen.dart';
import 'package:workhub_mobile/features/tasks/screens/task_detail_screen.dart';
import 'dashboard_reference_test.dart';

class WorkspaceAdapter extends ReferenceAdapter {
  bool failIdeas = false;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    Map<String, dynamic>? body;
    if (failIdeas && options.path.endsWith('/ec/today')) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    if (options.path.endsWith('/projects')) {
      body = {
        'data': [
          {
            'id': 1,
            'name': 'Supply Chain Excellence',
            'description':
                'Connect teams, improve fulfilment, and track shared milestones.',
            'progress': 65,
            'active_tasks': 8,
            'completed_tasks': 15,
            'status': 'in_progress'
          },
          {
            'id': 2,
            'name': 'People & Culture',
            'description': 'Stronger collaboration across every department.',
            'progress': 42,
            'active_tasks': 4,
            'completed_tasks': 3,
            'status': 'in_progress'
          },
        ]
      };
    } else if (options.path.endsWith('/payload')) {
      body = {
        'task': {
          'title': 'Prepare the weekly operations review',
          'description':
              'Review delivery milestones and confirm next steps with the team.',
          'status': 'in_progress',
          'status_name': 'In progress',
          'row_action': 'request_review',
          'priority_name': 'High',
          'complexity_name': 'Medium',
          'due_date': '2026-11-18',
          'project': {'name': 'Supply Chain Excellence'},
          'assignees': [
            {
              'employee': {'full_name': 'Budi Santosa'}
            }
          ],
          'attachments': [
            {'original_name': 'Operations review.pdf', 'size': 124800}
          ]
        }
      };
    } else if (options.path.endsWith('/comments')) {
      body = {
        'data': {
          'subject': {'can_comment': true},
          'comments': [
            {
              'comment_id': 1,
              'author': {'name': 'Budi Santosa'},
              'body': 'The latest milestones are ready for review.'
            },
            {
              'comment_id': 2,
              'author': {'name': 'Dewi Putri'},
              'body': 'Thank you. I will confirm the remaining delivery dates.'
            },
          ],
          'pagination': {'has_older': false}
        }
      };
    }
    if (body != null)
      return ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
    return super.fetch(options, stream, cancel);
  }
}

InboxItemModel workspaceItem() => InboxItemModel.fromJson({
      'id': 1,
      'module_code': 'sales-order',
      'subject_key': '1',
      'title': 'Delivery schedule confirmation',
      'subtitle':
          'Please review the delivery milestones and confirm the requested dates.',
      'status': 'pending',
      'created_at': '2026-11-13 16:40',
    });

Map<String, Widget> workspacePages() => {
      'inbox': const InboxScreen(isActive: false),
      'tasks': const TaskScreen(),
      'projects': const ProjectsScreen(),
      'inbox-detail': InboxItemDetailScreen(item: workspaceItem()),
      'task-detail': const TaskDetailScreen(taskId: 1),
    };

Widget workspaceApp(Widget page,
    {double scale = 1, WorkspaceAdapter? adapter}) {
  final storage = ReferenceStorage();
  final api = ApiClient(
      customDio: Dio()..httpClientAdapter = (adapter ?? WorkspaceAdapter()),
      customStorage: storage);
  return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => ReferenceAuth(api, storage)),
        reverbServiceProvider.overrideWith((ref) => ReferenceRealtime(api)),
      ],
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: OrbitTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: page));
}

void main() {
  for (final entry in workspacePages().entries) {
    testWidgets('${entry.key} keeps actions usable on phone widths',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(workspaceApp(entry.value));
      await tester.pumpAndSettle();
      expect(find.byType(OrbitWorkspaceScaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpWidget(workspaceApp(entry.value, scale: 1.4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('task search survives collapsing its filter panel',
      (tester) async {
    await tester.pumpWidget(workspaceApp(const TaskScreen()));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('task-board-filters-toggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('task-board-search'));
    await tester.enterText(field, 'operations');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final editable =
        find.descendant(of: field, matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(editable).controller.text, 'operations');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unavailable EC request does not escape a hidden panel',
      (tester) async {
    await tester.pumpWidget(workspaceApp(const TaskScreen(),
        adapter: WorkspaceAdapter()..failIdeas = true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared detail header retains native back navigation',
      (tester) async {
    await tester.pumpWidget(workspaceApp(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TaskDetailScreen(taskId: 1))),
                child: const Text('Open task'))))));
    await tester.tap(find.text('Open task'));
    await tester.pumpAndSettle();
    expect(find.text('Task details'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

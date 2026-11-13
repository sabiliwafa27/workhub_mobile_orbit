import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/tasks/screens/create_work_item_screen.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<ResponseBody>? pendingDraft;
  Completer<ResponseBody>? pendingSubmit;
  bool canCreate = true;
  bool canCustomizePoints = false;
  bool failTaskSubmission = false;
  bool teamOnlyAssignee = false;
  bool denyBootstrap = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (denyBootstrap && options.path.endsWith('/form-bootstrap')) {
      return ResponseBody.fromString('{}', 403, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    if (pendingSubmit != null && options.method == 'POST' && options.path.endsWith('/tasks')) return pendingSubmit!.future;
    if (failTaskSubmission && options.method == 'POST' && options.path.endsWith('/tasks')) {
      return ResponseBody.fromString('{}', 503, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    if (options.path.endsWith('/generate-draft') && pendingDraft != null) return pendingDraft!.future;
    final response = options.method == 'GET' ? {
      'bootstrap': {
        'employees': [if (!teamOnlyAssignee) {'employee_id': 7, 'full_name': 'Bob'}, {'employee_id': 8, 'full_name': 'Other'}],
        'teamStaff': [{'employee_id': 7, 'full_name': 'Bob'}],
        'actingForOptions': [{'employee_id': 50, 'full_name': 'Manager'}],
        'actingForManagerId': 50,
        'currentEmployeeId': 10,
        'canCustomizePoints': canCustomizePoints,
        'can': {'create': canCreate},
        'managerTokenBalance': 10,
        'projects': [{'project_id': 8, 'name': 'Project A'}],
        'priorities': [{'priority_code': 'normal', 'priority_name': 'Normal'}, {'priority_code': 'urgent', 'priority_name': 'Urgent'}],
        'complexities': [{'task_complexity_id': 2, 'complexity_value': 2, 'complexity_name': 'Medium'}],
      },
    } : options.path.endsWith('/generate-draft')
        ? {'title': 'Prepare Report', 'description': 'Prepare the monthly report.'}
        : {'message': 'Created', 'task': {'task_id': 1}};
    return ResponseBody.fromString(jsonEncode(response), options.method == 'GET' || options.path.endsWith('/generate-draft') ? 200 : 201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  testWidgets('quick and standard task forms fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = _Adapter(), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create'), 250, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager task controls fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = (_Adapter()..canCustomizePoints = true), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('5 points'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly recurrence controls fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = _Adapter(), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Does not repeat'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly on this weekday').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Repeat until'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick task defaults to the current employee and submits its description', (tester) async {
    final adapter = _Adapter();
    bool? result;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () async { result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateWorkItemScreen(projectId: 8))); },
        child: const Text('Open form'),
      ))))));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    expect(find.text('Project: Project A'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Task description'), 'Prepare report');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Open form'), findsOneWidget);
    final form = adapter.requests.last.data as FormData;
    expect(form.fields.any((field) => field.key == 'quick_task' && field.value == '1'), isTrue);
    expect(form.fields.any((field) => field.key == 'employee_ids[]' && field.value == '10'), isTrue);
    expect(form.fields.any((field) => field.key == 'project_id' && field.value == '8'), isTrue);
  });

  testWidgets('quick task mention selects the assignee', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Task description'), 'Please ask @Bo');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bob'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Task description')).controller!.text, 'Please ask @Bob ');
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('switching to standard starts with its own draft', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = _Adapter(), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Task description'), 'Quick draft');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).controller!.text, isEmpty);
    expect(find.text('Select an employee…'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Standard draft');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick Task'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Task description')).controller!.text, isEmpty);
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).controller!.text, 'Standard draft');
  });

  testWidgets('task form can clear a previously selected project', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateWorkItemScreen())),
        child: const Text('Open form'),
      ))))));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Prepare the monthly report');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate with Jarvis'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Select an employee…'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Assigned To'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bob'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No project'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('No project').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final posted = adapter.requests.last;
    final data = posted.data is String ? jsonDecode(posted.data as String) as Map : posted.data as Map;
    expect(data.containsKey('project_id'), isFalse);
  });

  testWidgets('participant removal requires confirmation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Search & add participants…'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Search & add participants…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InputChip, 'Other').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Remove participant?'), findsOneWidget);
    expect(find.text('Other'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Other'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Participant'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Other'), findsNothing);
  });

  testWidgets('task submission is disabled when bootstrap denies create access', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter()..canCreate = false;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Task creation is unavailable for your account.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(adapter.requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('task form explains a forbidden bootstrap response', (tester) async {
    final adapter = _Adapter()..denyBootstrap = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Task creation is unavailable for your account.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('uncertain task submission cannot be blindly repeated', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter()..failTaskSubmission = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Prepare the report');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate with Jarvis'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Assigned To'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('The result could not be confirmed. Check My Tasks before creating this task again.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('standard task controls are disabled while submitting', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter()..pendingSubmit = Completer<ResponseBody>();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Prepare report');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate with Jarvis'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Assigned To'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).enabled, isFalse);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Due date')).onTap, isNull);
    expect(tester.widget<PopScope>(find.byType(PopScope).first).canPop, isFalse);
    adapter.pendingSubmit!.complete(ResponseBody.fromString('{}', 422, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).enabled, isTrue);
    expect(tester.widget<PopScope>(find.byType(PopScope).first).canPop, isTrue);
  });

  test('standard task due date is two calendar days later', () {
    expect(standardTaskDueDate(DateTime(2024, 2, 28, 23, 55)), DateTime(2024, 3, 1));
    expect(standardTaskDueDate(DateTime(2026, 12, 30)), DateTime(2027, 1, 1));
  });

  testWidgets('authorized manager sees points change with priority', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter()..canCustomizePoints = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    expect(find.text('5 points'), findsOneWidget);
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urgent').last);
    await tester.pumpAndSettle();
    expect(find.text('8 points'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Assigned To'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bob'));
    await tester.pumpAndSettle();
    expect(find.text('8 points'), findsOneWidget);
  });

  testWidgets('team-only assignee remains visible after selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = (_Adapter()..teamOnlyAssignee = true), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Assigned To'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bob'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('making a task private requires confirmation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = _Adapter(), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private task'));
    await tester.pumpAndSettle();
    expect(find.text('Make this task private?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    await tester.tap(find.text('Private task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make Private'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
  });

  testWidgets('repeat controls follow the selected frequency', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = _Adapter(), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Repeat interval'), findsOneWidget);
    await tester.tap(find.text('Weekly').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Repeat interval'), findsNothing);
    expect(find.text('Repeat until'), findsOneWidget);
  });

  testWidgets('Jarvis does not overwrite edits made while a draft is loading', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter()..pendingDraft = Completer<ResponseBody>();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: CreateWorkItemScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'prepare report');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate with Jarvis'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'My revised instructions');
    adapter.pendingDraft!.complete(ResponseBody.fromString(jsonEncode({'title': 'AI title', 'description': 'AI description'}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
    await tester.pumpAndSettle();
    expect(find.text('My revised instructions'), findsOneWidget);
    expect(find.text('AI title'), findsNothing);
    expect(find.text('The form changed while Jarvis was working. Your edits were kept.'), findsOneWidget);
  });

  testWidgets('Jarvis draft fills the task title and description for review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: CreateWorkItemScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'prepare monthly report');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate with Jarvis'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare Report'), findsOneWidget);
    expect(find.text('Prepare the monthly report.'), findsOneWidget);
    expect(find.text('Review the title and description before creating the task.'), findsOneWidget);
  });

  testWidgets('task creation uses the selected assignee, project and acting manager', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(customDio: dio, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateWorkItemScreen(projectId: 8))),
        child: const Text('Open form'),
      )))),
    ));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Prepare the monthly report');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate with Jarvis'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Acting for'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Acting for'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Select an employee…'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Assigned To'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search employees'), 'Bo');
    await tester.pumpAndSettle();
    expect(find.text('Other'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Bob'));
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Search & add participants…'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search & add participants…'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(ListTile, 'Bob')), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Other'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final posted = adapter.requests.last;
    expect(posted.uri.path, '/workhub/api/v1/tasks');
    final data = posted.data is String ? jsonDecode(posted.data as String) as Map : posted.data as Map;
    expect(data['employee_ids'], [7]);
    expect(data['participant_ids'], [8]);
    expect(data['on_behalf_of_employee_id'], 50);
    expect(data['project_id'], 8);
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inbox_provider.dart';

class LogisticInOfficerForm extends ConsumerStatefulWidget {
  final String line;
  final int assignmentId;
  final String role;
  final List<String> packagingOptions;
  final List<String> yesNoOptions;
  final List<String> standardOptions;
  final Future<void> Function() refreshDetail;

  const LogisticInOfficerForm({super.key, required this.line, required this.assignmentId, required this.role,
    required this.packagingOptions, required this.yesNoOptions, required this.standardOptions, required this.refreshDetail});

  @override
  ConsumerState<LogisticInOfficerForm> createState() => _LogisticInOfficerFormState();
}

class _LogisticInOfficerFormState extends ConsumerState<LogisticInOfficerForm> {
  final form = GlobalKey<FormState>();
  final values = <String, String>{};
  final notes = <String, TextEditingController>{};
  DateTime? expiry;
  bool saving = false, uncertain = false, submitted = false;
  String? error;

  static const qcFields = <String, String>{'visual_appearance': 'Penampakan Visual', 'aroma': 'Aroma', 'texture': 'Tekstur', 'taste': 'Rasa', 'size': 'Ukuran', 'weight_test': 'Tes Berat', 'pressure_test': 'Tes Tekan'};
  static const vehicleFields = <String, String>{'vehicle_no_physical_damage': 'Armada bebas kerusakan fisik', 'vehicle_clean': 'Armada dalam kondisi bersih', 'vehicle_sealed_pest_free': 'Armada tertutup rapat', 'vehicle_not_for_non_food': 'Armada tidak membawa bahan non-food'};

  @override
  void dispose() { for (final controller in notes.values) { controller.dispose(); } super.dispose(); }

  TextEditingController controller(String key) => notes.putIfAbsent(key, TextEditingController.new);

  String label(String value) => switch (value) {
    'ya' => 'Ya', 'tidak' => 'Tidak', 'sesuai_standart' => 'Sesuai Standart',
    'tidak_sesuai_standart' => 'Tidak Sesuai Standart', 'tidak_diperlukan' => 'Tidak Diperlukan', _ => value,
  };

  Widget choice(String field, String title, List<String> options, {bool withNotes = true}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    DropdownButtonFormField<String>(
      value: values[field], isExpanded: true, decoration: InputDecoration(labelText: title),
      items: options.map((option) => DropdownMenuItem(value: option, child: Text(label(option)))).toList(),
      validator: (value) => value == null ? 'Select $title.' : null,
      onChanged: saving || uncertain || submitted ? null : (value) => setState(() { if (value != null) values[field] = value; }),
    ),
    if (withNotes) TextFormField(controller: controller('${field}_notes'), enabled: !saving && !uncertain && !submitted,
      maxLength: 2000, maxLines: 2, decoration: InputDecoration(labelText: '$title notes (optional)')),
  ]);

  Future<void> submit() async {
    if (saving || uncertain || submitted) return;
    if (expiry == null) { setState(() => error = 'Select the expiry date.'); return; }
    if (!(form.currentState?.validate() ?? false)) return;
    final data = <String, dynamic>{...values, 'expiry_date': expiry!.toIso8601String().split('T').first};
    for (final entry in notes.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) data[entry.key] = value;
    }
    setState(() { saving = true; error = null; });
    try {
      await ref.read(apiClientProvider).dio.post('/inbox/api/module-detail/wms.logistic-in/${Uri.encodeComponent(widget.line)}/assignments/${widget.assignmentId}/submit', data: data);
      if (!mounted) return;
      setState(() { submitted = true; saving = false; });
      ref.read(inboxNotifierProvider.notifier).loadInbox();
      try { await widget.refreshDetail(); } catch (_) { /* Submission succeeded; details can be refreshed later. */ }
    } on DioException catch (exception) {
      if (!mounted) return;
      final status = exception.response?.statusCode;
      final payload = exception.response?.data;
      final knownFailure = status != null && status >= 400 && status < 500 && status != 408 && status != 429;
      String? validationMessage;
      if (payload is Map && payload['errors'] is Map && (payload['errors'] as Map).isNotEmpty) {
        final first = (payload['errors'] as Map).values.first;
        if (first is List && first.isNotEmpty) validationMessage = first.first.toString();
      }
      setState(() {
        saving = false;
        uncertain = !knownFailure;
        error = knownFailure
            ? validationMessage ?? (payload is Map && payload['message'] is String ? payload['message'] as String : 'The form could not be submitted.')
            : 'Submission could not be confirmed. Refresh details before retrying.';
      });
    } catch (_) {
      if (mounted) setState(() { saving = false; uncertain = true; error = 'Submission could not be confirmed. Refresh details before retrying.'; });
    }
  }

  Future<void> refresh() async {
    setState(() => saving = true);
    try {
      await widget.refreshDetail();
      if (mounted) setState(() { uncertain = false; error = null; });
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to refresh details. Please try again.');
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final qc = widget.role == 'QC';
    final bm = widget.role == 'BM';
    return Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OrbitColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OrbitColors.cardBorder),
        ),
        child: Row(children: [
          const CircleAvatar(backgroundColor: OrbitColors.bubbleBlue,
              child: Icon(Icons.fact_check_outlined,
                  color: OrbitColors.primaryNavy)),
          const SizedBox(width: 12),
          Expanded(child: Text('${widget.role} officer input',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: OrbitColors.textNavy))),
        ]),
      ),
      const SizedBox(height: 12),
      ListTile(leading: const Icon(Icons.calendar_today_outlined,
          color: OrbitColors.primaryNavy), contentPadding: EdgeInsets.zero,
        title: const Text('Expiry date'), subtitle: Text(expiry?.toIso8601String().split('T').first ?? 'Select date'),
        onTap: saving || uncertain || submitted ? null : () async {
          final chosen = await showDatePicker(context: context, initialDate: expiry ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
          if (chosen != null && mounted) setState(() => expiry = chosen);
        }),
      choice('packaging_condition', 'Kemasan', widget.packagingOptions, withNotes: false),
      TextFormField(controller: controller('item_notes'), enabled: !saving && !uncertain && !submitted, maxLength: 2000, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Catatan kondisi item (optional)')),
      if (bm) for (final field in vehicleFields.entries) choice(field.key, field.value, widget.yesNoOptions),
      if (qc || bm) ...[
        choice('coa_available', 'COA', widget.yesNoOptions, withNotes: false),
        TextFormField(controller: controller('coa_notes'), enabled: !saving && !uncertain && !submitted, maxLength: 2000, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Catatan COA (optional)')),
      ],
      if (qc) for (final field in qcFields.entries) choice(field.key, field.value, widget.standardOptions),
      if (!qc) ...[
        choice('accept_item', 'Terima', widget.yesNoOptions, withNotes: false),
        TextFormField(controller: controller('accept_item_notes'), enabled: !saving && !uncertain && !submitted,
          keyboardType: const TextInputType.numberWithOptions(decimal: true), maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Received quantity'),
          validator: (value) {
            if (values['accept_item'] != 'ya') return null;
            final text = (value ?? '').trim();
            final valid = RegExp(r'^(?:\d+(?:\.\d{1,3})?|\.\d{1,3})$').hasMatch(text);
            return valid && (num.tryParse(text) ?? 0) > 0 ? null : 'Enter a quantity greater than zero with up to 3 decimal places.';
          }),
        choice('reject_item', 'Reject', widget.yesNoOptions),
      ],
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      if (submitted) const Text('Officer form submitted.'),
      if (uncertain) TextButton(onPressed: saving ? null : refresh, child: const Text('Refresh details')),
      if (!submitted) Align(alignment: Alignment.centerLeft, child: FilledButton(
        onPressed: saving || uncertain ? null : submit, child: Text(saving ? 'Submitting…' : 'Submit officer form'),
      )),
    ]));
  }
}

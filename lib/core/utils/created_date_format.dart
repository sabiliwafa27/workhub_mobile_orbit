import 'package:intl/intl.dart';

String formatCreatedDate(Object? value) {
  if (value == null) return '';
  final raw = value.toString().trim();
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : DateFormat('d MMMM yyyy').format(parsed);
}

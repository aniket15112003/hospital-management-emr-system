import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final _date = DateFormat('dd MMM yyyy');
final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
final _time = DateFormat('hh:mm a');
final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Accepts Firestore [Timestamp], [DateTime], or null.
DateTime? asDateTime(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String formatDate(Object? v) {
  final d = asDateTime(v);
  return d == null ? '—' : _date.format(d);
}

String formatDateTime(Object? v) {
  final d = asDateTime(v);
  return d == null ? '—' : _dateTime.format(d);
}

String formatTime(Object? v) {
  final d = asDateTime(v);
  return d == null ? '—' : _time.format(d);
}

String formatMoney(Object? v) => v is num ? _money.format(v) : '—';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

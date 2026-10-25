import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/formatters.dart';

/// Future modules that feed dashboard metrics. Flip a flag to `true` when the
/// module ships and writes the collection described in docs/ADMIN_PANEL.md;
/// the queries below are already written against that contract.
enum SourceModule {
  registration('Patient Registration (Receptionist) module'),
  opd('OPD / Doctor EMR module'),
  lab('Laboratory module'),
  pharmacy('Pharmacy module'),
  billing('Billing & Payments module');

  const SourceModule(this.label);
  final String label;
}

const implementedSources = <SourceModule, bool>{
  SourceModule.registration: false,
  SourceModule.opd: false,
  SourceModule.lab: false,
  SourceModule.pharmacy: false,
  SourceModule.billing: false,
};

/// A metric that may not have a data source yet.
class Metric<T> {
  const Metric.available(T this.value, {this.demo = false}) : reason = null;
  const Metric.unavailable(String this.reason) : value = null, demo = false;

  final T? value;
  final String? reason;

  /// True when the value is sample data (demo mode).
  final bool demo;

  bool get isAvailable => reason == null;

  static Metric<T> notBuilt<T>(SourceModule m) =>
      Metric.unavailable('${m.label} is not implemented yet.');
}

class QueueRow {
  const QueueRow(
    this.doctor,
    this.department,
    this.waiting,
    this.inProgress,
    this.completed,
  );
  final String doctor;
  final String department;
  final int waiting;
  final int inProgress;
  final int completed;
}

class VisitRow {
  const VisitRow(this.number, this.patient, this.kind, this.doctor, this.at);
  final String number;
  final String patient;

  /// `registration` or `opd`.
  final String kind;
  final String doctor;
  final DateTime? at;
}

class PendingRow {
  const PendingRow(
    this.number,
    this.patient,
    this.detail,
    this.at,
    this.status,
  );
  final String number;
  final String patient;
  final String detail;
  final DateTime? at;
  final String status;
}

class CollectionSummary {
  const CollectionSummary(this.total, this.receipts, this.byMethod);
  final num total;
  final int receipts;
  final Map<String, num> byMethod;
}

class LowStockRow {
  const LowStockRow(this.medicine, this.stock, this.threshold);
  final String medicine;
  final num stock;
  final num threshold;
}

abstract class DashboardSource {
  Future<Metric<int>> registrationsToday();
  Future<Metric<int>> opdEncountersToday();
  Future<Metric<List<QueueRow>>> queue();
  Future<Metric<List<VisitRow>>> recentVisits();
  Future<Metric<List<PendingRow>>> pendingLabOrders();
  Future<Metric<List<PendingRow>>> pendingPrescriptions();
  Future<Metric<CollectionSummary>> collectionToday();
  Future<Metric<List<LowStockRow>>> lowStock();
}

/// Firestore-backed source. Each method returns "unavailable" until its
/// module is marked implemented in [implementedSources].
class FirestoreDashboardSource implements DashboardSource {
  FirestoreDashboardSource(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  bool _on(SourceModule m) => implementedSources[m] ?? false;

  ({Timestamp from, Timestamp to}) get _today {
    final start = startOfDay(_clock());
    return (
      from: Timestamp.fromDate(start),
      to: Timestamp.fromDate(start.add(const Duration(days: 1))),
    );
  }

  Query<Map<String, dynamic>> _todayQuery(String col, String field) => _db
      .collection(col)
      .where(field, isGreaterThanOrEqualTo: _today.from)
      .where(field, isLessThan: _today.to);

  Future<int> _count(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  @override
  Future<Metric<int>> registrationsToday() async {
    if (!_on(SourceModule.registration)) {
      return Metric.notBuilt(SourceModule.registration);
    }
    return Metric.available(
      await _count(_todayQuery('patients', 'registeredAt')),
    );
  }

  @override
  Future<Metric<int>> opdEncountersToday() async {
    if (!_on(SourceModule.opd)) return Metric.notBuilt(SourceModule.opd);
    return Metric.available(
      await _count(_todayQuery('opd_encounters', 'encounterAt')),
    );
  }

  @override
  Future<Metric<List<QueueRow>>> queue() async {
    if (!_on(SourceModule.opd)) return Metric.notBuilt(SourceModule.opd);
    final snap = await _todayQuery('opd_encounters', 'encounterAt').get();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final d in snap.docs) {
      groups.putIfAbsent('${d.data()['doctorId']}', () => []).add(d.data());
    }
    return Metric.available([
      for (final g in groups.values)
        QueueRow(
          '${g.first['doctorName'] ?? '—'}',
          '${g.first['departmentName'] ?? '—'}',
          g.where((e) => e['queueStatus'] == 'waiting').length,
          g.where((e) => e['queueStatus'] == 'in_consultation').length,
          g.where((e) => e['queueStatus'] == 'completed').length,
        ),
    ]);
  }

  @override
  Future<Metric<List<VisitRow>>> recentVisits() async {
    if (!_on(SourceModule.opd)) return Metric.notBuilt(SourceModule.opd);
    final snap = await _todayQuery(
      'opd_encounters',
      'encounterAt',
    ).orderBy('encounterAt', descending: true).limit(10).get();
    return Metric.available([
      for (final d in snap.docs)
        VisitRow(
          '${d.data()['encounterNumber'] ?? d.id}',
          '${d.data()['patientName'] ?? '—'}',
          'opd',
          '${d.data()['doctorName'] ?? '—'}',
          asDateTime(d.data()['encounterAt']),
        ),
    ]);
  }

  Future<Metric<List<PendingRow>>> _pending(
    SourceModule m,
    String col,
    String numberField,
    String detailField,
    String atField,
    List<String> statuses,
  ) async {
    if (!_on(m)) return Metric.notBuilt(m);
    final snap = await _db
        .collection(col)
        .where('status', whereIn: statuses)
        .orderBy(atField)
        .limit(25)
        .get();
    return Metric.available([
      for (final d in snap.docs)
        PendingRow(
          '${d.data()[numberField] ?? d.id}',
          '${d.data()['patientName'] ?? '—'}',
          '${d.data()[detailField] ?? ''}',
          asDateTime(d.data()[atField]),
          '${d.data()['status']}',
        ),
    ]);
  }

  @override
  Future<Metric<List<PendingRow>>> pendingLabOrders() => _pending(
    SourceModule.lab,
    'lab_orders',
    'orderNumber',
    'testSummary',
    'orderedAt',
    ['ordered', 'sample_collected', 'in_progress'],
  );

  @override
  Future<Metric<List<PendingRow>>> pendingPrescriptions() => _pending(
    SourceModule.pharmacy,
    'pharmacy_prescriptions',
    'prescriptionNumber',
    'doctorName',
    'createdAt',
    ['pending', 'partially_dispensed'],
  );

  @override
  Future<Metric<CollectionSummary>> collectionToday() async {
    if (!_on(SourceModule.billing)) {
      return Metric.notBuilt(SourceModule.billing);
    }
    final snap = await _todayQuery(
      'payments',
      'receivedAt',
    ).where('status', isEqualTo: 'completed').get();
    num total = 0;
    final byMethod = <String, num>{};
    for (final d in snap.docs) {
      final amount = (d.data()['amount'] as num?) ?? 0;
      total += amount;
      final m = '${d.data()['paymentMethodName'] ?? 'Other'}';
      byMethod[m] = (byMethod[m] ?? 0) + amount;
    }
    return Metric.available(CollectionSummary(total, snap.size, byMethod));
  }

  @override
  Future<Metric<List<LowStockRow>>> lowStock() async {
    if (!_on(SourceModule.pharmacy)) {
      return Metric.notBuilt(SourceModule.pharmacy);
    }
    final snap = await _db
        .collection('medicine_stock')
        .where('belowThreshold', isEqualTo: true)
        .limit(25)
        .get();
    return Metric.available([
      for (final d in snap.docs)
        LowStockRow(
          '${d.data()['medicineName'] ?? d.id}',
          (d.data()['quantity'] as num?) ?? 0,
          (d.data()['threshold'] as num?) ?? 0,
        ),
    ]);
  }
}

/// Explicit demo mode only: sample values flagged as demo.
class DemoDashboardSource implements DashboardSource {
  DateTime _at(int minutesAgo) =>
      DateTime.now().subtract(Duration(minutes: minutesAgo));

  @override
  Future<Metric<int>> registrationsToday() async =>
      const Metric.available(18, demo: true);

  @override
  Future<Metric<int>> opdEncountersToday() async =>
      const Metric.available(42, demo: true);

  @override
  Future<Metric<List<QueueRow>>> queue() async => const Metric.available([
    QueueRow('Dr. Asha Rao', 'General Medicine', 6, 1, 14),
    QueueRow('Dr. Vikram Shah', 'Cardiology', 3, 1, 8),
    QueueRow('Dr. Meera Iyer', 'Orthopaedics', 2, 0, 5),
    QueueRow('Dr. Karan Mehta', 'Paediatrics', 4, 1, 9),
  ], demo: true);

  @override
  Future<Metric<List<VisitRow>>> recentVisits() async => Metric.available([
    VisitRow('OPD-0042', 'Sample Patient A', 'opd', 'Dr. Asha Rao', _at(4)),
    VisitRow('UHID-0018', 'Sample Patient B', 'registration', '—', _at(9)),
    VisitRow('OPD-0041', 'Sample Patient C', 'opd', 'Dr. Vikram Shah', _at(15)),
  ], demo: true);

  @override
  Future<Metric<List<PendingRow>>> pendingLabOrders() async =>
      Metric.available([
        PendingRow(
          'LAB-0102',
          'Sample Patient C',
          'CBC, FBS',
          _at(40),
          'sample_collected',
        ),
        PendingRow(
          'LAB-0103',
          'Sample Patient D',
          'Urine Routine',
          _at(25),
          'ordered',
        ),
      ], demo: true);

  @override
  Future<Metric<List<PendingRow>>> pendingPrescriptions() async =>
      Metric.available([
        PendingRow(
          'RX-0311',
          'Sample Patient A',
          'Dr. Asha Rao',
          _at(5),
          'pending',
        ),
      ], demo: true);

  @override
  Future<Metric<CollectionSummary>> collectionToday() async =>
      const Metric.available(
        CollectionSummary(28450, 37, {
          'Cash': 12200,
          'UPI': 14250,
          'Card': 2000,
        }),
        demo: true,
      );

  @override
  Future<Metric<List<LowStockRow>>> lowStock() async => const Metric.available([
    LowStockRow('Amoxicillin 250 mg', 12, 30),
    LowStockRow('Cetirizine Syrup', 6, 20),
  ], demo: true);
}

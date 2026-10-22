import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderCode => text()();
  TextColumn get productName => text()();
  IntColumn get quantity => integer()();
  RealColumn get totalPrice => real()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()(); // UTC millis
}

/// Data profil akun (tidak sensitif). Password disimpan terpisah di secure storage.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text()();
  TextColumn get email => text().unique()();
  TextColumn get phone => text()();
  IntColumn get createdAt => integer()(); // UTC millis
}

@DriftDatabase(tables: [Orders, Users])
class AppDb extends _$AppDb {
  AppDb() : super(driftDatabase(name: 'kateringkita'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: tambah tabel users tanpa menghapus data orders lama.
          if (from < 2) await m.createTable(users);
        },
      );

  // ---------------- USERS ----------------
  Future<User?> findUserByEmail(String email) =>
      (select(users)..where((t) => t.email.equals(email.trim().toLowerCase())))
          .getSingleOrNull();

  Future<int> addUser({
    required String fullName,
    required String email,
    required String phone,
  }) =>
      into(users).insert(UsersCompanion.insert(
        fullName: fullName.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      ));

  // ---------------- ORDERS ----------------

  Stream<List<Order>> watchOrders() => (select(orders)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  Future<int> addOrder({
    required String orderCode,
    required String productName,
    required int quantity,
    required double totalPrice,
  }) =>
      into(orders).insert(OrdersCompanion.insert(
        orderCode: orderCode,
        productName: productName,
        quantity: quantity,
        totalPrice: totalPrice,
        updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      ));

  Future<void> upsertAll(List<OrdersCompanion> rows) => transaction(() async {
        for (final r in rows) {
          await into(orders).insertOnConflictUpdate(r);
        }
      });

  Future<void> markSynced(List<int> ids) =>
      (update(orders)..where((t) => t.id.isIn(ids)))
          .write(const OrdersCompanion(synced: Value(true)));

  Future<void> updateOrderStatus(int id, String status) =>
      (update(orders)..where((t) => t.id.equals(id)))
          .write(OrdersCompanion(
            status: Value(status),
            updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          ));

  Future<void> deleteOrder(int id) =>
      (delete(orders)..where((t) => t.id.equals(id))).go();
}
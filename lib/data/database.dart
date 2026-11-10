import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// テーブル定義
// ---------------------------------------------------------------------------

/// カテゴリ(自由に追加できる)。
/// Flutter の foundation に `Category` クラスがあるため、データクラス名は PlaceCategory にしている。
@DataClassName('PlaceCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// エリア(選択式。管理画面から追加・並べ替えできる)。
class Areas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// お店・観光地のメモ本体。
class Places extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();
  IntColumn get areaId =>
      integer().nullable().references(Areas, #id, onDelete: KeyAction.setNull)();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get memo => text().withDefault(const Constant(''))();

  /// 誰と行きたいか。
  TextColumn get wantWith => text().withDefault(const Constant(''))();

  /// スクショのファイル名(アプリ内 images フォルダからの相対名)。
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 訪問記録(いつ・誰と・評価)。1つの場所に何回でも記録できる。
class Visits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get placeId =>
      integer().references(Places, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get visitedOn => dateTime()();
  TextColumn get companions => text().withDefault(const Constant(''))();

  /// 1〜5。未評価は null。
  IntColumn get rating => integer().nullable()();
  TextColumn get comment => text().withDefault(const Constant(''))();
}

// ---------------------------------------------------------------------------
// 画面に渡すためのクラス
// ---------------------------------------------------------------------------

enum MasterKind {
  category('カテゴリ'),
  area('エリア');

  const MasterKind(this.label);
  final String label;
}

class MasterItem {
  const MasterItem(this.id, this.name);
  final int id;
  final String name;
}

/// 一覧表示用:場所 + カテゴリ/エリア名 + 訪問の集計。
class PlaceSummary {
  const PlaceSummary({
    required this.place,
    required this.category,
    required this.area,
    required this.visitCount,
    required this.lastVisit,
    required this.avgRating,
  });

  final Place place;
  final PlaceCategory? category;
  final Area? area;
  final int visitCount;
  final DateTime? lastVisit;
  final double? avgRating;

  bool get visited => visitCount > 0;
}

class PlaceInput {
  const PlaceInput({
    required this.name,
    this.categoryId,
    this.areaId,
    this.address = '',
    this.url = '',
    this.memo = '',
    this.wantWith = '',
    this.imagePath,
  });

  final String name;
  final int? categoryId;
  final int? areaId;
  final String address;
  final String url;
  final String memo;
  final String wantWith;
  final String? imagePath;
}

class VisitInput {
  const VisitInput({
    required this.placeId,
    required this.visitedOn,
    this.companions = '',
    this.rating,
    this.comment = '',
  });

  final int placeId;
  final DateTime visitedOn;
  final String companions;
  final int? rating;
  final String comment;
}

// ---------------------------------------------------------------------------
// 初期データ
// ---------------------------------------------------------------------------

const _defaultCategories = [
  'カフェ',
  'レストラン',
  'スイーツ',
  'バー・居酒屋',
  '観光地',
  'ショップ',
  'その他',
];

const _defaultAreas = [
  '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県', //
  '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
  '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県',
  '静岡県', '愛知県', '三重県', '滋賀県', '京都府', '大阪府', '兵庫県',
  '奈良県', '和歌山県', '鳥取県', '島根県', '岡山県', '広島県', '山口県',
  '徳島県', '香川県', '愛媛県', '高知県', '福岡県', '佐賀県', '長崎県',
  '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県', '海外',
];

// ---------------------------------------------------------------------------
// データベース本体
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Categories, Areas, Places, Visits])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'place_memo');

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await batch((b) {
            b.insertAll(categories, [
              for (final (i, name) in _defaultCategories.indexed)
                CategoriesCompanion.insert(name: name, sortOrder: Value(i)),
            ]);
            b.insertAll(areas, [
              for (final (i, name) in _defaultAreas.indexed)
                AreasCompanion.insert(name: name, sortOrder: Value(i)),
            ]);
          });
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---------------- 場所 ----------------

  /// 一覧用。訪問記録が増えたり消えたりしても自動で流れ直す。
  Stream<List<PlaceSummary>> watchPlaceSummaries() {
    final visitCount = visits.id.count();
    final lastVisit = visits.visitedOn.max();
    final avgRating = visits.rating.avg();

    final query = select(places).join([
      leftOuterJoin(categories, categories.id.equalsExp(places.categoryId)),
      leftOuterJoin(areas, areas.id.equalsExp(places.areaId)),
      leftOuterJoin(visits, visits.placeId.equalsExp(places.id),
          useColumns: false),
    ])
      ..addColumns([visitCount, lastVisit, avgRating])
      ..groupBy([places.id])
      ..orderBy([OrderingTerm.desc(places.updatedAt)]);

    return query.watch().map((rows) => [
          for (final r in rows)
            PlaceSummary(
              place: r.readTable(places),
              category: r.readTableOrNull(categories),
              area: r.readTableOrNull(areas),
              visitCount: r.read(visitCount) ?? 0,
              lastVisit: r.read(lastVisit),
              avgRating: r.read(avgRating),
            ),
        ]);
  }

  Future<int> insertPlace(PlaceInput p) {
    return into(places).insert(PlacesCompanion.insert(
      name: p.name,
      categoryId: Value(p.categoryId),
      areaId: Value(p.areaId),
      address: Value(p.address),
      url: Value(p.url),
      memo: Value(p.memo),
      wantWith: Value(p.wantWith),
      imagePath: Value(p.imagePath),
    ));
  }

  Future<void> updatePlace(int id, PlaceInput p) {
    return (update(places)..where((t) => t.id.equals(id))).write(
      PlacesCompanion(
        name: Value(p.name),
        categoryId: Value(p.categoryId),
        areaId: Value(p.areaId),
        address: Value(p.address),
        url: Value(p.url),
        memo: Value(p.memo),
        wantWith: Value(p.wantWith),
        imagePath: Value(p.imagePath),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deletePlace(int id) {
    return transaction(() async {
      await (delete(visits)..where((t) => t.placeId.equals(id))).go();
      await (delete(places)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------- 訪問記録 ----------------

  Stream<List<Visit>> watchVisits(int placeId) {
    return (select(visits)
          ..where((t) => t.placeId.equals(placeId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.visitedOn),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Future<int> insertVisit(VisitInput v) {
    return into(visits).insert(VisitsCompanion.insert(
      placeId: v.placeId,
      visitedOn: v.visitedOn,
      companions: Value(v.companions),
      rating: Value(v.rating),
      comment: Value(v.comment),
    ));
  }

  Future<void> updateVisit(int id, VisitInput v) {
    return (update(visits)..where((t) => t.id.equals(id))).write(
      VisitsCompanion(
        visitedOn: Value(v.visitedOn),
        companions: Value(v.companions),
        rating: Value(v.rating),
        comment: Value(v.comment),
      ),
    );
  }

  Future<void> deleteVisit(int id) {
    return (delete(visits)..where((t) => t.id.equals(id))).go();
  }

  // ---------------- カテゴリ / エリア ----------------

  Stream<List<MasterItem>> watchMasters(MasterKind kind) {
    return switch (kind) {
      MasterKind.category => (select(categories)
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch()
          .map((rows) => [for (final r in rows) MasterItem(r.id, r.name)]),
      MasterKind.area => (select(areas)
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch()
          .map((rows) => [for (final r in rows) MasterItem(r.id, r.name)]),
    };
  }

  /// 追加したものは末尾に並ぶ。
  Future<int> addMaster(MasterKind kind, String name) {
    final order = DateTime.now().millisecondsSinceEpoch;
    return switch (kind) {
      MasterKind.category => into(categories).insert(
          CategoriesCompanion.insert(name: name, sortOrder: Value(order))),
      MasterKind.area => into(areas)
          .insert(AreasCompanion.insert(name: name, sortOrder: Value(order))),
    };
  }

  Future<void> renameMaster(MasterKind kind, int id, String name) async {
    switch (kind) {
      case MasterKind.category:
        await (update(categories)..where((t) => t.id.equals(id)))
            .write(CategoriesCompanion(name: Value(name)));
      case MasterKind.area:
        await (update(areas)..where((t) => t.id.equals(id)))
            .write(AreasCompanion(name: Value(name)));
    }
  }

  /// 削除すると、そのカテゴリ/エリアが付いていたメモからは外れる(メモ自体は残る)。
  Future<void> deleteMaster(MasterKind kind, int id) {
    return transaction(() async {
      switch (kind) {
        case MasterKind.category:
          await (update(places)..where((t) => t.categoryId.equals(id)))
              .write(const PlacesCompanion(categoryId: Value(null)));
          await (delete(categories)..where((t) => t.id.equals(id))).go();
        case MasterKind.area:
          await (update(places)..where((t) => t.areaId.equals(id)))
              .write(const PlacesCompanion(areaId: Value(null)));
          await (delete(areas)..where((t) => t.id.equals(id))).go();
      }
    });
  }

  Future<void> reorderMasters(MasterKind kind, List<int> orderedIds) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        switch (kind) {
          case MasterKind.category:
            await (update(categories)..where((t) => t.id.equals(id)))
                .write(CategoriesCompanion(sortOrder: Value(i)));
          case MasterKind.area:
            await (update(areas)..where((t) => t.id.equals(id)))
                .write(AreasCompanion(sortOrder: Value(i)));
        }
      }
    });
  }
}

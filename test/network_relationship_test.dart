import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/network_graph_layout.dart';
import 'package:insurance_helper/services/relationship_kinds.dart';
import 'package:insurance_helper/services/relationship_rows.dart';

Map<String, dynamic> person(String id, String name, {String? referrer}) {
  return {'id': id, 'name': name, 'referral_source_id': referrer};
}

Map<String, dynamic> relation(String id, String source, String target, String type, String detail) {
  return {
    'id': id,
    'source_customer_id': source,
    'target_customer_id': target,
    'relationship_type': type,
    'relationship_detail': detail,
  };
}

void main() {
  group('人脈圖：同一對人合成一條線（2026-11-08 老師、沛沛）', () {
    test('朋友又是轉介紹：一條線、朋友的顏色、有箭頭指向被介紹的人', () {
      final NetworkGraph graph = NetworkGraph.build(
        [person('mei', '王美華'), person('chen', '陳志豪', referrer: 'mei')],
        [relation('r1', 'mei', 'chen', 'social', '朋友')],
      );
      expect(graph.edges.length, 1);
      final NetworkGraphEdge edge = graph.edges.single;
      expect(edge.type, 'social');
      expect(edge.label, '朋友・介紹');
      expect(edge.referrer?.id, 'mei');
      expect(edge.referred?.id, 'chen');
    });

    test('只有轉介紹：線用轉介紹的顏色', () {
      final NetworkGraph graph = NetworkGraph.build(
        [person('mei', '王美華'), person('wu', '吳雅婷', referrer: 'mei')],
        const [],
      );
      expect(graph.edges.single.type, 'referral');
      expect(graph.edges.single.label, '介紹');
    });

    test('篩選：隱藏朋友但顯示轉介紹時，朋友又是轉介紹的線還在', () {
      final NetworkGraph graph = NetworkGraph.build(
        [person('mei', '王美華'), person('chen', '陳志豪', referrer: 'mei')],
        [relation('r1', 'mei', 'chen', 'social', '朋友')],
      );
      final NetworkGraphEdge edge = graph.edges.single;
      expect(edge.isVisible({'social'}), isTrue);
      expect(edge.showsArrow({'social'}), isTrue);
      expect(edge.isVisible({'social', 'referral'}), isFalse);
    });

    test('兩種一般關係合在一起寫；子女、父母線上寫親子', () {
      final NetworkGraph graph = NetworkGraph.build(
        [person('a', '甲'), person('b', '乙')],
        [relation('r1', 'a', 'b', 'family', '子女'), relation('r2', 'b', 'a', 'workplace', '同事')],
      );
      expect(graph.edges.single.label, '親子・同事');
    });
  });

  group('關係稱呼與管理關係清單', () {
    test('子女從對方看是父母；舊資料的自由文字照原樣', () {
      final Map<String, dynamic> record = relation('r1', 'mei', 'kid', 'family', '子女');
      expect(RelationshipKinds.labelFor('mei', record), '子女');
      expect(RelationshipKinds.labelFor('kid', record), '父母');
      expect(RelationshipKinds.labelFor('kid', relation('r2', 'mei', 'kid', 'family', '母子')), '母子');
    });

    test('一位對方一列：朋友＋王美華介紹的；被介紹的那邊寫介紹了陳志豪', () {
      final List<Map<String, dynamic>> customers = [
        person('mei', '王美華'),
        person('chen', '陳志豪', referrer: 'mei'),
      ];
      final List<Map<String, dynamic>> relationships = [relation('r1', 'mei', 'chen', 'social', '朋友')];
      final RelationshipRow fromMei =
          RelationshipRows.build(viewerId: 'mei', customers: customers, relationships: relationships).single;
      expect(fromMei.describe('王美華'), '朋友・王美華介紹的');
      final RelationshipRow fromChen =
          RelationshipRows.build(viewerId: 'chen', customers: customers, relationships: relationships).single;
      expect(fromChen.describe('陳志豪'), '朋友・介紹了陳志豪');
      expect(fromChen.relationshipIds, ['r1']);
    });
  });
}

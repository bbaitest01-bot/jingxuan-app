import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/customer_service.dart';

// 建立測試用客戶
Map<String, dynamic> buildCustomer(String id, String name, String phone, {String notes = ''}) {
  return {
    'id': id,
    'name': name,
    'nickname': '',
    'phone': phone,
    'notes': notes,
    'agent_name': '',
    'tags': <String>[],
    'deleted_at': null,
  };
}

// 用搜尋文字篩選，回傳找到的客戶 id
List<String> searchIds(List<Map<String, dynamic>> customers, String query) {
  final List<Map<String, dynamic>> result = CustomerService.instance.filterCustomers(
    allCustomers: customers,
    query: query.trim().toLowerCase(),
    onlyMine: false,
    currentUserId: null,
  );
  return result.map((customer) => customer['id'] as String).toList();
}

void main() {
  final List<Map<String, dynamic>> customers = [
    buildCustomer('a', '王小明', '0912-345-678'),
    buildCustomer('b', '林小華', '0987654321'),
    buildCustomer('c', '陳大文', '(02) 2345-6789'),
  ];

  test('電話片段：有沒有「-」都找得到（C-05）', () {
    expect(searchIds(customers, '345'), containsAll(['a', 'c']));
    expect(searchIds(customers, '0912-345'), ['a']);
    expect(searchIds(customers, '0912345678'), ['a']);
    expect(searchIds(customers, '0987-654'), ['b']);
  });

  test('不存在的號碼找不到（C-06）', () {
    expect(searchIds(customers, '0000'), isEmpty);
  });

  test('備註裡有這串數字仍會被找到', () {
    final List<Map<String, dynamic>> withNotes = [
      buildCustomer('d', '張三', '0911111111', notes: '舊號碼 0000-123'),
    ];
    expect(searchIds(withNotes, '0000'), ['d']);
  });

  test('姓名加數字的搜尋不會被拆成電話比對', () {
    expect(searchIds(customers, '王1'), isEmpty);
  });

  test('姓名搜尋照常可用', () {
    expect(searchIds(customers, '小明'), ['a']);
  });

  test('只輸入符號時當作還沒搜尋，顯示全部客戶', () {
    expect(searchIds(customers, '-'), ['a', 'b', 'c']);
    expect(searchIds(customers, '( )'), ['a', 'b', 'c']);
  });

  test('phoneDigits 只留數字', () {
    expect(CustomerService.phoneDigits('(02) 2345-6789'), '0223456789');
  });
}

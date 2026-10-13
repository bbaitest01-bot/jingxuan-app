/// 標籤的資料模型：大分類（TagCategoryModel）與子標籤（TagItemModel）
class TagCategoryModel {
  final String id;
  final String name;
  final String? colorHex;
  final int sortOrder;

  TagCategoryModel({
    required this.id,
    required this.name,
    this.colorHex,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'sortOrder': sortOrder,
      };

  factory TagCategoryModel.fromJson(Map<String, dynamic> json) => TagCategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        colorHex: json['colorHex'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

class TagItemModel {
  final String id;
  final String categoryId;
  final String name;
  final String? colorHex;
  final int usageCount;

  TagItemModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.colorHex,
    this.usageCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'name': name,
        'colorHex': colorHex,
        'usageCount': usageCount,
      };

  factory TagItemModel.fromJson(Map<String, dynamic> json) => TagItemModel(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String? ?? 'cat_identity',
        name: json['name'] as String,
        colorHex: json['colorHex'] as String?,
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      );

  TagItemModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? colorHex,
    int? usageCount,
  }) {
    return TagItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

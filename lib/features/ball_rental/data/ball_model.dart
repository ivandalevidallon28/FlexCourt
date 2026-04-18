class Ball {
  final String id;
  final String name;
  /// `AVAILABLE` or `IN_USE` (sync with public.balls.status).
  final String status;
  final DateTime createdAt;

  Ball({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  factory Ball.fromMap(Map<String, dynamic> map) => Ball(
        id: map['id'] as String,
        name: map['name'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'].toString()),
      );

  bool get isAvailable => status == 'AVAILABLE';
}

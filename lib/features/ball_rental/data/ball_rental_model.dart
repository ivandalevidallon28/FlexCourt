class BallRental {
  final String id;
  final String ballId;
  final String userId;
  final int amount;
  /// `ACTIVE` or `COMPLETED`.
  final String status;
  final DateTime createdAt;
  final DateTime? returnedAt;
  final DateTime? paidAt;
  final String? ballName;

  BallRental({
    required this.id,
    required this.ballId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.returnedAt,
    this.paidAt,
    this.ballName,
  });

  factory BallRental.fromMap(Map<String, dynamic> map) {
    final ballNested = map['balls'] as Map<String, dynamic>?;
    return BallRental(
      id: map['id'] as String,
      ballId: map['ball_id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toInt(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'].toString()),
      returnedAt: map['returned_at'] != null
          ? DateTime.tryParse(map['returned_at'].toString())
          : null,
      paidAt: map['paid_at'] != null
          ? DateTime.tryParse(map['paid_at'].toString())
          : null,
      ballName: ballNested?['name'] as String?,
    );
  }

  bool get isActive => status == 'ACTIVE';
}

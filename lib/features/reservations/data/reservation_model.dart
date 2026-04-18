class Reservation {
  final String id;
  final String courtId;
  final String? categoryId;
  final String userId;
  final String eventType;
  final int playersCount;
  final DateTime date;
  final String status;
  final double price;
  final double? totalAmount;
  final String startTime;
  final String endTime;
  final String paymentStatus;
  final String? paymentReceiptPath;
  final DateTime? paymentReceiptUploadedAt;
  final DateTime? paymentDueAt;
  final DateTime? paidAt;

  Reservation({
    required this.id,
    required this.courtId,
    this.categoryId,
    required this.userId,
    required this.eventType,
    required this.playersCount,
    required this.date,
    required this.status,
    required this.price,
    this.totalAmount,
    required this.startTime,
    required this.endTime,
    this.paymentStatus = 'UNPAID',
    this.paymentReceiptPath,
    this.paymentReceiptUploadedAt,
    this.paymentDueAt,
    this.paidAt,
  });

  factory Reservation.fromMap(Map<String, dynamic> map) => Reservation(
        id: map['id'] as String,
        courtId: map['court_id'] as String,
        categoryId: map['category_id'] as String?,
        userId: map['user_id'] as String,
        eventType: map['event_type'] as String,
        playersCount: map['players_count'] as int,
        date: DateTime.parse(map['date'] as String),
        status: map['status'] as String,
        price: (map['price'] as num).toDouble(),
        totalAmount: (map['total_amount'] as num?)?.toDouble(),
        startTime: map['start_time'] as String,
        endTime: map['end_time'] as String,
        paymentStatus: (map['payment_status'] as String?) ?? 'UNPAID',
        paymentReceiptPath: map['payment_receipt_path'] as String?,
        paymentReceiptUploadedAt: map['payment_receipt_uploaded_at'] != null
            ? DateTime.tryParse(
                map['payment_receipt_uploaded_at'].toString(),
              )
            : null,
        paymentDueAt: map['payment_due_at'] != null
            ? DateTime.tryParse(map['payment_due_at'].toString())
            : null,
        paidAt: map['paid_at'] != null
            ? DateTime.tryParse(map['paid_at'].toString())
            : null,
      );
}


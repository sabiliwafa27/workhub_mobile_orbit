class VisitTargetModel {
  final String visitTargetUuid;
  final int customerId;
  final String customerUuid;
  final String customerName;
  final String customerCode;
  final String phone;
  final String address;
  final double latitude;
  final double longitude;
  final String status;
  final String? checkedInAt;
  final String? photoThumbnailUrl;

  VisitTargetModel({
    required this.visitTargetUuid,
    required this.customerId,
    required this.customerUuid,
    required this.customerName,
    required this.customerCode,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.checkedInAt,
    this.photoThumbnailUrl,
  });

  factory VisitTargetModel.fromJson(Map<String, dynamic> json) {
    return VisitTargetModel(
      visitTargetUuid: json['visit_target_uuid'] as String,
      customerId: json['customer_id'] as int,
      customerUuid: json['customer_uuid'] as String,
      customerName: json['customer_name'] as String,
      customerCode: json['customer_code'] as String,
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      checkedInAt: json['checked_in_at'] as String?,
      photoThumbnailUrl: json['photo_thumbnail_url'] as String?,
    );
  }

  bool get isCheckedIn => status == 'checked_in';
}

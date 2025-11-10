class BalanceDetails {
  final String accountId;
  final String customerName;
  final String customerClass;
  final String? mobileNumber;
  final String? emailId;
  final String accountType;
  final double balanceRemaining;
  final String connectionStatus;
  final String customerType;
  final double? minRecharge;

  BalanceDetails({
    required this.accountId,
    required this.customerName,
    required this.customerClass,
    this.mobileNumber,
    this.emailId,
    required this.accountType,
    required this.balanceRemaining,
    required this.connectionStatus,
    required this.customerType,
    this.minRecharge,
  });

  factory BalanceDetails.fromJson(Map<String, dynamic> json) {
    return BalanceDetails(
      accountId: json['accountId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerClass: json['customerClass'] ?? '',
      mobileNumber: json['mobileNumber'],
      emailId: json['emailId'],
      accountType: json['accountType'] ?? '',
      balanceRemaining: _parseDouble(json['balanceRemaining']),
      connectionStatus: json['connectionStatus'] ?? '',
      customerType: json['customerType'] ?? '',
      minRecharge: _parseDoubleNullable(json['minRecharge']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'customerName': customerName,
      'customerClass': customerClass,
      'mobileNumber': mobileNumber,
      'emailId': emailId,
      'accountType': accountType,
      'balanceRemaining': balanceRemaining,
      'connectionStatus': connectionStatus,
      'customerType': customerType,
      'minRecharge': minRecharge,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String getFormattedBalance() {
    return '৳ ${balanceRemaining.toStringAsFixed(2)}';
  }

  String getFormattedMinRecharge() {
    if (minRecharge == null) return 'N/A';
    return '৳ ${minRecharge!.toStringAsFixed(2)}';
  }
}

class AccountModel {
  final String id;
  final String accountNumber;
  final String accountName;
  final String accountType;
  final String currency;
  final double balance;
  final double availableBalance;
  final String status;
  final bool isDefault;
  final DateTime createdAt;

  AccountModel({
    required this.id,
    required this.accountNumber,
    required this.accountName,
    required this.accountType,
    required this.currency,
    required this.balance,
    required this.availableBalance,
    required this.status,
    required this.isDefault,
    required this.createdAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] ?? '',
      accountNumber: json['account_number'] ?? '',
      accountName: json['account_name'] ?? '',
      accountType: json['account_type'] ?? 'checking',
      currency: json['currency'] ?? 'DZD',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      availableBalance: double.tryParse(json['available_balance']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'active',
      isDefault: json['is_default'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String getFormattedBalance() => '$balance $currency';
}
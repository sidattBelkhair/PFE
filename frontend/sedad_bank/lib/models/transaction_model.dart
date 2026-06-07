class TransactionModel {
  final String id;
  final String fromAccountName;
  final String toAccountName;
  final String? toBeneficiaryName;
  final String transactionType;
  final double amount;
  final String currency;
  final String status;
  final String? description;
  final DateTime createdAt;
  final String? referenceNumber;
  final bool isCredit;

  TransactionModel({
    required this.id,
    required this.fromAccountName,
    required this.toAccountName,
    this.toBeneficiaryName,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.status,
    this.description,
    required this.createdAt,
    this.referenceNumber,
    this.isCredit = false,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json, {bool isCredit = false}) {
    return TransactionModel(
      id: json['id'] ?? '',
      fromAccountName: json['from_account_name'] ?? 'Compte',
      toAccountName: json['to_account_name'] ?? '',
      toBeneficiaryName: json['to_beneficiary_name'],
      transactionType: json['transaction_type'] ?? 'transfer',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] ?? 'MRU',
      status: json['status'] ?? 'pending',
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      referenceNumber: json['reference_number'],
      isCredit: isCredit,
    );
  }

  String get counterpartLabel {
    if (isCredit) return 'De : $fromAccountName';
    if (toAccountName.isNotEmpty) return 'Vers : $toAccountName';
    if (toBeneficiaryName != null && toBeneficiaryName!.isNotEmpty) {
      return 'Vers : $toBeneficiaryName';
    }
    return description ?? transactionType;
  }

  String getFormattedAmount() => '$amount $currency';
  String getFormattedDate() => createdAt.toIso8601String().split('T')[0];
}
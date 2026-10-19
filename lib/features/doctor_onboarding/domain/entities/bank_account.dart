/// Where a doctor's consultation payouts are sent.
class BankAccount {
  const BankAccount({
    this.bankName = '',
    this.accountHolderName = '',
    this.accountNumber = '',
    this.routingCode = '',
    this.upiId = '',
  });

  static const int minAccountNumberLength = 9;
  static const int maxAccountNumberLength = 18;

  final String bankName;
  final String accountHolderName;

  /// Digits only.
  final String accountNumber;

  /// IFSC in India, routing or sort code elsewhere.
  final String routingCode;

  /// Optional second payout route, e.g. `sarahjenkins@okaxis`.
  final String upiId;

  String? get bankNameError =>
      bankName.trim().isEmpty ? 'Enter your bank name.' : null;

  String? get accountHolderNameError => accountHolderName.trim().isEmpty
      ? 'Enter the name on the account.'
      : null;

  String? get accountNumberError {
    final number = accountNumber.trim();
    if (number.isEmpty) return 'Enter your account number.';
    if (!RegExp(r'^\d+$').hasMatch(number)) return 'Digits only.';
    if (number.length < minAccountNumberLength ||
        number.length > maxAccountNumberLength) {
      return 'An account number is $minAccountNumberLength to '
          '$maxAccountNumberLength digits.';
    }
    return null;
  }

  String? get routingCodeError {
    final code = routingCode.trim().toUpperCase();
    if (code.isEmpty) return 'Enter your IFSC or routing code.';
    if (!RegExp(r'^[A-Z0-9]{6,15}$').hasMatch(code)) {
      return 'That code does not look right.';
    }
    return null;
  }

  /// Optional, so only a malformed entry is an error.
  String? get upiIdError {
    final upi = upiId.trim();
    if (upi.isEmpty) return null;
    if (!RegExp(r"^[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}$").hasMatch(upi)) {
      return 'A UPI ID looks like name@bank.';
    }
    return null;
  }

  bool get isComplete =>
      bankNameError == null &&
      accountHolderNameError == null &&
      accountNumberError == null &&
      routingCodeError == null &&
      upiIdError == null;

  /// `•••• 7890` — all the app ever shows back to the doctor.
  String get maskedAccountNumber {
    final number = accountNumber.trim();
    if (number.length <= 4) return number;
    return '•••• ${number.substring(number.length - 4)}';
  }

  BankAccount copyWith({
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? routingCode,
    String? upiId,
  }) {
    return BankAccount(
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      routingCode: routingCode ?? this.routingCode,
      upiId: upiId ?? this.upiId,
    );
  }
}

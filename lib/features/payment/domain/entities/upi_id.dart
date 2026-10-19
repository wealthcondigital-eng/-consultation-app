/// A UPI virtual payment address, e.g. `amit.verma@okaxis`.
class UpiId {
  const UpiId(this.value);

  const UpiId.empty() : value = '';

  final String value;

  /// `handle@bank` — the shape every UPI address takes.
  static final RegExp _pattern = RegExp(r'^[\w.\-]{2,}@[A-Za-z]{2,}$');

  bool get isEmpty => value.trim().isEmpty;

  /// Well-formed enough to send for verification. Whether the address actually
  /// exists is the backend's answer, not this one's.
  bool get isWellFormed => _pattern.hasMatch(value.trim());

  @override
  bool operator ==(Object other) => other is UpiId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

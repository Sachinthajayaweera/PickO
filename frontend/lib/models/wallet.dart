class Wallet {
  final String userId;
  final double availableBalance;
  final double lockedEscrowBalance;

  Wallet({
    required this.userId,
    required this.availableBalance,
    required this.lockedEscrowBalance,
  });

  double get totalBalance => availableBalance + lockedEscrowBalance;

  Wallet copyWith({
    String? userId,
    double? availableBalance,
    double? lockedEscrowBalance,
  }) {
    return Wallet(
      userId: userId ?? this.userId,
      availableBalance: availableBalance ?? this.availableBalance,
      lockedEscrowBalance: lockedEscrowBalance ?? this.lockedEscrowBalance,
    );
  }
}

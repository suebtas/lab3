String formatBaht(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  var count = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    buffer.write(digits[i]);
    count++;
    if (count % 3 == 0 && i != 0) {
      buffer.write(',');
    }
  }
  final withCommas = buffer.toString().split('').reversed.join();
  return amount < 0 ? '-฿$withCommas' : '฿$withCommas';
}
import 'package:intl/intl.dart';

class CurrencyHelper {
  CurrencyHelper._();

  static final NumberFormat _rmFormatter = NumberFormat.currency(
    locale: 'ms_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  static String formatRM(num amount) => _rmFormatter.format(amount);
}

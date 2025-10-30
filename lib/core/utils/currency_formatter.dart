import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat.simpleCurrency();

  static String format(num value) {
    return _formatter.format(value);
  }
}

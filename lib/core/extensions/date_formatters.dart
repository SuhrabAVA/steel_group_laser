import 'package:intl/intl.dart';

extension DateFormatters on DateTime {
  String toExplorerDate() {
    return DateFormat('dd.MM.yyyy HH:mm').format(toLocal());
  }
}

// https://github.com/nodatime/nodatime/blob/master/src/NodaTime/Fields/FixedLengthDatePeriodField.cs
// fa6874e  on Dec 8, 2017

import 'package:meta/meta.dart';
import 'package:quiver_hashcode/hashcode.dart';

import 'package:time_machine/time_machine.dart';
import 'package:time_machine/time_machine_utilities.dart';
import 'package:time_machine/time_machine_calendars.dart';
import 'package:time_machine/time_machine_fields.dart';

/// Date period field for fixed-length periods (weeks and days).
@internal /*sealed*/ class FixedLengthDatePeriodField implements IDatePeriodField {
  final int _unitDays;

  @internal FixedLengthDatePeriodField(this._unitDays);

  LocalDate Add(LocalDate localDate, int value) {
    if (value == 0) {
      return localDate;
    }
    int daysToAdd = value * _unitDays;
    var calendar = localDate.Calendar;
    // If we know it will be in this year, next year, or the previous year...
    if (daysToAdd < 300 && daysToAdd > -300) {
      YearMonthDayCalculator calculator = calendar.yearMonthDayCalculator;
      YearMonthDay yearMonthDay = localDate.yearMonthDay;
      int year = yearMonthDay.year;
      int month = yearMonthDay.month;
      int day = yearMonthDay.day;
      int newDayOfMonth = day + daysToAdd;
      if (1 <= newDayOfMonth && newDayOfMonth <= calculator.getDaysInMonth(year, month)) {
        return new LocalDate.trusted(new YearMonthDayCalendar(year, month, newDayOfMonth, calendar.ordinal));
      }
      int dayOfYear = calculator.getDayOfYear(yearMonthDay);
      int newDayOfYear = dayOfYear + daysToAdd;

      if (newDayOfYear < 1) {
        newDayOfYear += calculator.getDaysInYear(year - 1);
        year--;
        if (year < calculator.minYear) {
          throw new RangeError("Date computation would underflow the minimum year of the calendar");
        }
      }
      else {
        int daysInYear = calculator.getDaysInYear(year);
        if (newDayOfYear > daysInYear) {
          newDayOfYear -= daysInYear;
          year++;
          if (year > calculator.maxYear) {
            throw new RangeError("Date computation would overflow the maximum year of the calendar");
          }
        }
      }
      return new LocalDate.trusted(calculator.getYearMonthDay(year, newDayOfYear).WithCalendarOrdinal(calendar.ordinal));
    }
    // LocalDate constructor will validate.
    int days = localDate.DaysSinceEpoch + daysToAdd;
    return new LocalDate.fromDaysSinceEpoch_forCalendar(days, calendar);
  }

  int UnitsBetween(LocalDate start, LocalDate end) =>
      Period.DaysBetween(start, end) ~/ _unitDays;
}
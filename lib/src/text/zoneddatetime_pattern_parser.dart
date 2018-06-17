// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'package:time_machine/time_machine.dart';
import 'package:time_machine/time_machine_utilities.dart';
import 'package:time_machine/time_machine_globalization.dart';
import 'package:time_machine/time_machine_timezones.dart';
import 'package:time_machine/time_machine_text.dart';
import 'package:time_machine/time_machine_patterns.dart';

@internal class ZonedDateTimePatternParser implements IPatternParser<ZonedDateTime> {
  final ZonedDateTime _templateValue;
  final IDateTimeZoneProvider _zoneProvider;
  final ZoneLocalMappingResolver _resolver;

  static final Map<String /*char*/, CharacterHandler<ZonedDateTime, _ZonedDateTimeParseBucket>> _patternCharacterHandlers =
  {
    '%': SteppedPatternBuilder.handlePercent /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '\'': SteppedPatternBuilder.handleQuote /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '\"': SteppedPatternBuilder.handleQuote /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '\\': SteppedPatternBuilder.handleBackslash /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '/': (pattern, builder) => builder.addLiteral1(builder.formatInfo.dateSeparator, ParseResult.dateSeparatorMismatch /**<ZonedDateTime>*/),
    'T': (pattern, builder) => builder.addLiteral2('T', ParseResult.mismatchedCharacter /**<ZonedDateTime>*/),
    'y': DatePatternHelper.createYearOfEraHandler<ZonedDateTime, _ZonedDateTimeParseBucket>((value) => value.yearOfEra, (bucket, value) =>
    bucket.Date.yearOfEra = value),
    'u': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, _ZonedDateTimeParseBucket>(
        4, PatternFields.year, -9999, 9999, (value) => value.year, (bucket, value) => bucket.Date.year = value),
    'M': DatePatternHelper.createMonthOfYearHandler<ZonedDateTime, _ZonedDateTimeParseBucket>((value) => value.month, (bucket, value) =>
    bucket.Date.monthOfYearText = value, (bucket, value) => bucket.Date.monthOfYearNumeric = value),
    'd': DatePatternHelper.createDayHandler<ZonedDateTime, _ZonedDateTimeParseBucket>((value) => value.day, (value) => value.dayOfWeek.value, (bucket, value) =>
    bucket.Date.dayOfMonth = value, (bucket, value) => bucket.Date.dayOfWeek = value),
    '.': TimePatternHelper.createPeriodHandler<ZonedDateTime, _ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.fractionalSeconds = value),
    ';': TimePatternHelper.createCommaDotHandler<ZonedDateTime, _ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.fractionalSeconds = value),
    ':': (pattern, builder) => builder.addLiteral1(builder.formatInfo.timeSeparator, ParseResult.timeSeparatorMismatch /**<ZonedDateTime>*/),
    'h': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, _ZonedDateTimeParseBucket>(
        2, PatternFields.hours12, 1, 12, (value) => value.clockHourOfHalfDay, (bucket, value) => bucket.Time.hours12 = value),
    'H': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, _ZonedDateTimeParseBucket>(
        2, PatternFields.hours24, 0, 24, (value) => value.hour, (bucket, value) => bucket.Time.hours24 = value),
    'm': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, _ZonedDateTimeParseBucket>(
        2, PatternFields.minutes, 0, 59, (value) => value.minute, (bucket, value) => bucket.Time.minutes = value),
    's': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, _ZonedDateTimeParseBucket>(
        2, PatternFields.seconds, 0, 59, (value) => value.second, (bucket, value) => bucket.Time.seconds = value),
    'f': TimePatternHelper.createFractionHandler<ZonedDateTime, _ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.fractionalSeconds = value),
    'F': TimePatternHelper.createFractionHandler<ZonedDateTime, _ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.fractionalSeconds = value),
    't': TimePatternHelper.createAmPmHandler<ZonedDateTime, _ZonedDateTimeParseBucket>((time) => time.hour, (bucket, value) => bucket.Time.amPm = value),
    'c': DatePatternHelper.createCalendarHandler<ZonedDateTime, _ZonedDateTimeParseBucket>((value) => value.localDateTime.calendar, (bucket, value) =>
    bucket.Date.calendar = value),
    'g': DatePatternHelper.createEraHandler<ZonedDateTime, _ZonedDateTimeParseBucket>((value) => value.era, (bucket) => bucket.Date),
    'z': _handleZone,
    'x': _handleZoneAbbreviation,
    'o': _handleOffset,
    'l': (cursor, builder) => builder.addEmbeddedLocalPartial(
        cursor, (bucket) => bucket.Date, (bucket) => bucket.Time, (value) => value.date, (value) => value.timeOfDay, (value) => value.localDateTime),
  };

  @internal ZonedDateTimePatternParser(this._templateValue, this._resolver, this._zoneProvider);

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  IPattern<ZonedDateTime> parsePattern(String patternText, TimeMachineFormatInfo formatInfo) {
    // Nullity check is performed in ZonedDateTimePattern.
    if (patternText.length == 0) {
      throw new InvalidPatternError(TextErrorMessages.formatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length == 1) {
      switch (patternText[0]) {
        case 'G':
          return ZonedDateTimePatterns.generalFormatOnlyPatternImpl
              .withZoneProvider(_zoneProvider)
              .withResolver(_resolver);
        case 'F':
          return ZonedDateTimePatterns.extendedFormatOnlyPatternImpl
              .withZoneProvider(_zoneProvider)
              .withResolver(_resolver);
        default:
          throw new InvalidPatternError.format(TextErrorMessages.unknownStandardFormat, [patternText[0], 'ZonedDateTime']);
      }
    }

    var patternBuilder = new SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimeParseBucket>(formatInfo,
            () => new _ZonedDateTimeParseBucket(_templateValue, _resolver, _zoneProvider));
    if (_zoneProvider == null || _resolver == null) {
      patternBuilder.setFormatOnly();
    }
    patternBuilder.parseCustomPattern(patternText, _patternCharacterHandlers);
    patternBuilder.validateUsedFields();
    return patternBuilder.build(_templateValue);
  }

  static void _handleZone(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimeParseBucket> builder) {
    builder.addField(PatternFields.zone, pattern.current);
    builder.addParseAction(_parseZone);
    builder.addFormatAction((value, sb) => sb.write(value.zone.id));
  }

  static void _handleZoneAbbreviation(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimeParseBucket> builder) {
    builder.addField(PatternFields.zoneAbbreviation, pattern.current);
    builder.setFormatOnly();
    builder.addFormatAction((value, sb) =>
        sb.write(value
            .getZoneInterval()
            .name));
  }

  static void _handleOffset(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimeParseBucket> builder) {
    builder.addField(PatternFields.embeddedOffset, pattern.current);
    String embeddedPattern = pattern.getEmbeddedPattern();
    var offsetPattern = OffsetPattern
        .create(embeddedPattern, builder.formatInfo)
        .underlyingPattern;
    builder.addEmbeddedPattern(offsetPattern, (bucket, offset) => bucket.offset = offset, (zdt) => zdt.offset);
  }

  static ParseResult<ZonedDateTime> _parseZone(ValueCursor value, _ZonedDateTimeParseBucket bucket) => bucket.ParseZone(value);
}

class _ZonedDateTimeParseBucket extends ParseBucket<ZonedDateTime> {
  @internal final /*LocalDatePatternParser.*/LocalDateParseBucket Date;
  @internal final /*LocalTimePatternParser.*/LocalTimeParseBucket Time;
  DateTimeZone _zone;
  @internal Offset offset;
  final ZoneLocalMappingResolver _resolver;
  final IDateTimeZoneProvider _zoneProvider;

  @internal _ZonedDateTimeParseBucket(ZonedDateTime templateValue, this._resolver, this._zoneProvider)
      : Date = new /*LocalDatePatternParser.*/LocalDateParseBucket(templateValue.date),
        Time = new /*LocalTimePatternParser.*/LocalTimeParseBucket(templateValue.timeOfDay),
        _zone = templateValue.zone;


  @internal ParseResult<ZonedDateTime> ParseZone(ValueCursor value) {
    DateTimeZone zone = _tryParseFixedZone(value) ?? _tryParseProviderZone(value);

    if (zone == null) {
      return ParseResult.noMatchingZoneId<ZonedDateTime>(value);
    }
    _zone = zone;
    return null;
  }

  /// Attempts to parse a fixed time zone from "UTC" with an optional
  /// offset, expressed as +HH, +HH:mm, +HH:mm:ss or +HH:mm:ss.fff - i.e. the
  /// general format. If it manages, it will move the cursor and return the
  /// zone. Otherwise, it will return null and the cursor will remain where
  /// it was.
  DateTimeZone _tryParseFixedZone(ValueCursor value) {
    if (value.compareOrdinal(DateTimeZone.utcId) != 0) {
      return null;
    }
    value.move(value.index + 3);
    var pattern = OffsetPattern.generalInvariant.underlyingPattern;
    var parseResult = pattern.parsePartial(value);
    return parseResult.success ? new DateTimeZone.forOffset(parseResult.value) : DateTimeZone.utc;
  }

  /// Tries to parse a time zone ID from the provider. Returns the zone
  /// on success (after moving the cursor to the end of the ID) or null on failure
  /// (leaving the cursor where it was).
  DateTimeZone _tryParseProviderZone(ValueCursor value) {
    // The IDs from the provider are guaranteed to be in order (using ordinal comparisons).
    // Use a binary search to find a match, then make sure it's the longest possible match.
    var ids = _zoneProvider.ids;
    int lowerBound = 0; // Inclusive
    int upperBound = ids.length; // Exclusive
    while (lowerBound < upperBound) {
      int guess = (lowerBound + upperBound) ~/ 2;
      int result = value.compareOrdinal(ids[guess]);
      if (result < 0) {
        // Guess is later than our text: lower the upper bound
        upperBound = guess;
      }
      else if (result > 0) {
        // Guess is earlier than our text: raise the lower bound
        lowerBound = guess + 1;
      }
      else {
        // We've found a match! But it may not be as long as it
        // could be. Keep track of a "longest match so far" (starting with the match we've found),
        // and keep looking through the IDs until we find an ID which doesn't start with that "longest
        // match so far", at which point we know we're done.
        //
        // We can't just look through all the IDs from "guess" to "lowerBound" and stop when we hit
        // a non-match against "value", because of situations like this:
        // value=Etc/GMT-12
        // guess=Etc/GMT-1
        // IDs includes { Etc/GMT-1, Etc/GMT-10, Etc/GMT-11, Etc/GMT-12, Etc/GMT-13 }
        // We can't stop when we hit Etc/GMT-10, because otherwise we won't find Etc/GMT-12.
        // We *can* stop when we get to Etc/GMT-13, because by then our longest match so far will
        // be Etc/GMT-12, and we know that anything beyond Etc/GMT-13 won't match that.
        // We can also stop when we hit upperBound, without any more comparisons.
        String longestSoFar = ids[guess];
        for (int i = guess + 1; i < upperBound; i++) {
          String candidate = ids[i];
          if (candidate.length < longestSoFar.length) {
            break;
          }
          if (stringOrdinalCompare(longestSoFar, 0, candidate, 0, longestSoFar.length) != 0) {
            break;
          }
          if (value.compareOrdinal(candidate) == 0) {
            longestSoFar = candidate;
          }
        }
        value.move(value.index + longestSoFar.length);
        return _zoneProvider.getDateTimeZoneSync(longestSoFar); // [longestSoFar];
      }
    }
    return null;
  }

  @internal
  @override
  ParseResult<ZonedDateTime> calculateValue(PatternFields usedFields, String text) {
    var localResult = /*LocalDateTimePatternParser.*/LocalDateTimeParseBucket.combineBuckets(usedFields, Date, Time, text);
    if (!localResult.success) {
      return localResult.convertError<ZonedDateTime>();
    }

    var localDateTime = localResult.value;

    // No offset - so just use the resolver
    if ((usedFields & PatternFields.embeddedOffset).value == 0) {
      try {
        return ParseResult.forValue<ZonedDateTime>(_zone.resolveLocal(localDateTime, _resolver));
      }
      on SkippedTimeError {
        return ParseResult.skippedLocalTime<ZonedDateTime>(text);
      }
      on AmbiguousTimeError {
        return ParseResult.ambiguousLocalTime<ZonedDateTime>(text);
      }
    }

    // We were given an offset, so we can resolve and validate using that
    var mapping = _zone.mapLocal(localDateTime);
    ZonedDateTime result;
    switch (mapping.count) {
      // If the local time was skipped, the offset has to be invalid.
      case 0:
        return ParseResult.invalidOffset<ZonedDateTime>(text);
      case 1:
        result = mapping.first(); // We'll validate in a minute
        break;
      case 2:
        result = mapping
            .first()
            .offset == offset ? mapping.first() : mapping.last();
        break;
      default:
        throw new /*InvalidOperationException*/ StateError("Mapping has count outside range 0-2; should not happen.");
    }
    if (result.offset != offset) {
      return ParseResult.invalidOffset<ZonedDateTime>(text);
    }
    return ParseResult.forValue<ZonedDateTime>(result);
  }
}


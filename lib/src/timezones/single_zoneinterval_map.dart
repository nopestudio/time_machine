// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'package:time_machine/time_machine.dart';
import 'package:time_machine/time_machine_timezones.dart';

/// Implementation of IZoneIntervalMap which just returns a single interval (provided on construction) regardless of
/// the instant requested.
@immutable
@internal class SingleZoneIntervalMap implements IZoneIntervalMap {
  final ZoneInterval _interval;

  @internal SingleZoneIntervalMap(this._interval);

  ZoneInterval getZoneInterval(Instant instant) => _interval;
}


// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tara Rider';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get notifications => 'Notifications';

  @override
  String get recenterMap => 'Recenter the map';

  @override
  String get safetyAlert => 'Safety alert';

  @override
  String callPerson(String name) {
    return 'Call $name';
  }

  @override
  String digitLabel(int index) {
    return 'Digit $index';
  }

  @override
  String get currencyFcfa => 'FCFA';

  @override
  String get tabHome => 'Home';

  @override
  String get tabActivity => 'Activity';

  @override
  String get tabProfile => 'Profile';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get goOnlineLabel => 'You are offline. Go online';

  @override
  String get goOfflineLabel => 'You are online. Go offline';

  @override
  String get goOnline => 'Go online';

  @override
  String secondsRemaining(int seconds) {
    return 'Time left to accept: $seconds seconds';
  }

  @override
  String get seconds => 'seconds';

  @override
  String get sosHoldLabel => 'Hold for 3 seconds to send an alert';

  @override
  String get sosHold => 'Hold 3 s';

  @override
  String sosHoldRemaining(int seconds) {
    return '$seconds s more…';
  }

  @override
  String get sosSent => 'Sent';

  @override
  String get offlineBannerTitle => 'Offline';

  @override
  String offlineBannerPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending actions',
      one: '1 pending action',
      zero: 'No pending action',
    );
    return '$_temp0 · saved on the phone';
  }

  @override
  String get catalogTitle => 'Component catalogue';

  @override
  String get stepPickup => 'Pickup';

  @override
  String get stepCollect => 'Payment';

  @override
  String get stepDelivery => 'Delivery';

  @override
  String get cash => 'Cash';

  @override
  String get mobileMoney => 'Mobile Money';

  @override
  String get periodDay => 'Day';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get searchingJobs => 'Looking for jobs…';

  @override
  String get searchingJobsHint => 'Stay in the area, offers will show up here.';

  @override
  String get stepDone => 'done';

  @override
  String get stepActive => 'in progress';

  @override
  String get stepUpcoming => 'upcoming';
}

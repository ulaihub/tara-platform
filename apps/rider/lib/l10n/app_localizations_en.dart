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

  @override
  String get riderSpace => 'RIDER SPACE';

  @override
  String get signInTitle => 'Ready to hit the road?';

  @override
  String get signInBody => 'Sign in with your number. We will text you a code.';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '6XX XX XX XX';

  @override
  String countryCodeLabel(String code) {
    return 'Country code $code';
  }

  @override
  String get phoneHelp => 'Use the number linked to your Mobile Money account: your earnings are paid to it.';

  @override
  String get phoneInvalid => '9-digit Cameroonian mobile number starting with 6.';

  @override
  String get getCode => 'Get the code';

  @override
  String get legalPrefix => 'By continuing, you accept the ';

  @override
  String get terms => 'terms of use';

  @override
  String get legalAnd => ' and the ';

  @override
  String get privacy => 'privacy policy';

  @override
  String get codeTitle => 'Enter the code you received';

  @override
  String codeSentTo(String phone) {
    return 'Sent by SMS to $phone';
  }

  @override
  String get change => 'Change';

  @override
  String resendIn(String time) {
    return 'Resend the code in $time';
  }

  @override
  String get resendNow => 'Didn’t get anything?';

  @override
  String get resend => 'Resend';

  @override
  String get validate => 'Confirm';

  @override
  String get noSms => 'No SMS? Contact support';

  @override
  String get continueLabel => 'Continue';

  @override
  String stepOf(int step, int total, String name) {
    return 'Step $step of $total · $name';
  }

  @override
  String get stepProfile => 'Profile';

  @override
  String get stepDocuments => 'Documents';

  @override
  String get becomeRider => 'Become a Tara rider';

  @override
  String get becomeRiderBody => 'A few details to create your profile. Everything is checked before your first job.';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get vehicle => 'Vehicle';

  @override
  String get vehicleMotorbike => 'Motorbike';

  @override
  String get vehicleCar => 'Car';

  @override
  String get vehicleTricycle => 'Tricycle';

  @override
  String get plateNumber => 'Plate number';

  @override
  String get plateHint => 'E.g. LT 123 AB';

  @override
  String get guarantor => 'Guarantor';

  @override
  String get guarantorHelp => 'A trusted person who vouches for you. Their ID will be requested.';

  @override
  String get guarantorName => 'Guarantor’s name';

  @override
  String get guarantorPhone => 'Guarantor’s phone';

  @override
  String get emergencyContact => 'Emergency contact (optional)';

  @override
  String get emergencyHelp => 'Notified automatically if you trigger an alert.';

  @override
  String get emergencyName => 'Contact name';

  @override
  String get emergencyPhone => 'Contact phone';

  @override
  String get requiredField => 'Required';

  @override
  String get documentsTitle => 'Your documents';

  @override
  String get documentsBody => 'Photograph each document, flat and readable.';

  @override
  String get docSent => 'Sent';

  @override
  String get docToDo => 'To send';

  @override
  String docUploading(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get docRejected => 'Rejected';

  @override
  String get docApproved => 'Approved';

  @override
  String get docExpired => 'Expired';

  @override
  String get takePhoto => 'Take';

  @override
  String get sendAgain => 'Resend';

  @override
  String docAlternative(String name) {
    return 'or $name';
  }

  @override
  String get documentsNote =>
      'Your documents are encrypted and checked by the Tara team. You get an SMS once approved.';

  @override
  String get sendFile => 'Submit my application';

  @override
  String progressCount(int done, int total) {
    return '$done / $total';
  }

  @override
  String get pendingTitle => 'Application under review';

  @override
  String get pendingBody =>
      'We are checking your documents, usually within 48 h. You will get an SMS as soon as you can take jobs.';

  @override
  String get goodMorning => 'Good morning,';

  @override
  String get goodEvening => 'Good evening,';

  @override
  String get todayEarnings => 'Today’s earnings';

  @override
  String get details => 'Details';

  @override
  String jobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
      zero: 'No jobs',
    );
    return '$_temp0';
  }

  @override
  String get onlineTime => 'Online';

  @override
  String get cashInHand => 'Cash in hand';

  @override
  String get youAreOffline => 'You are offline';

  @override
  String get offlineHint => 'Go online to receive job offers around you.';

  @override
  String get locationNeeded => 'Turn on location to go online.';

  @override
  String get blockersTitle => 'Documents to renew before going online';

  @override
  String get retry => 'Retry';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get networkError => 'No internet connection. Check the network and try again.';

  @override
  String jobsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'jobs', one: 'job');
    return '$_temp0';
  }

  @override
  String get logout => 'Sign out';

  @override
  String get suspendedTitle => 'Account suspended';

  @override
  String get suspendedBody => 'Your account cannot take jobs right now. Contact Tara support to learn more.';

  @override
  String get goOffline => 'Go offline';

  @override
  String get callSupport => 'Call support';
}

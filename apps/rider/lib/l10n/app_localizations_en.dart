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

  @override
  String get noMotoZone => 'No motorbikes';

  @override
  String get searchingTitle => 'Looking for jobs…';

  @override
  String get today => 'Today';

  @override
  String get newJob => 'New job';

  @override
  String get yourEarning => 'Your earning';

  @override
  String pickupLabel(String distance) {
    return 'PICKUP · $distance';
  }

  @override
  String dropoffLabel(String distance, int minutes) {
    return 'DELIVERY · $distance · ~$minutes min';
  }

  @override
  String toCollect(String amount) {
    return 'To collect: $amount';
  }

  @override
  String get decline => 'Decline';

  @override
  String get accept => 'Accept';

  @override
  String get packageSmall => 'Small parcel';

  @override
  String get packageMedium => 'Medium parcel';

  @override
  String get packageLarge => 'Large parcel';

  @override
  String get fragile => 'Fragile';

  @override
  String get express => 'Express';

  @override
  String get offerTaken => 'Job given to another rider';

  @override
  String get offerExpired => 'Time is up: the job goes to another rider';

  @override
  String get vehicleShort => 'Motorbike';

  @override
  String get toPickup => 'To pickup';

  @override
  String toPickupMinutes(int minutes) {
    return 'To pickup · $minutes min';
  }

  @override
  String get directions => 'Directions';

  @override
  String get openWith => 'Open directions with';

  @override
  String get collectAtPickupTitle => 'Collect at pickup';

  @override
  String get collectAtPickupBody => 'In cash, before taking the parcel.';

  @override
  String get noMotoAddress => 'Address in a no-motorbike zone: park outside and finish on foot.';

  @override
  String get pickupCodeLabel => 'Pickup code';

  @override
  String get pickupCodeHint => 'given by the sender';

  @override
  String get photoParcel => 'Photograph the parcel';

  @override
  String get photoParcelHint => 'Tara label visible';

  @override
  String photoParcelTaken(String time) {
    return 'Parcel photo · taken at $time';
  }

  @override
  String get retakePhoto => 'Retake';

  @override
  String get parcelCollected => 'Parcel collected';

  @override
  String get actionSavedOffline => 'Saved on the phone: sent automatically when the network is back.';

  @override
  String get noPositionYet => 'Looking for your position: wait a few seconds outdoors.';

  @override
  String get orderCancelledNotice => 'Job cancelled by the sender.';

  @override
  String get orderReassignedNotice => 'Job given to another rider.';

  @override
  String courseInProgress(String reference) {
    return 'Job $reference in progress';
  }

  @override
  String get courseResume => 'Resume';

  @override
  String courseRefRecorded(String reference) {
    return 'Job $reference · route recorded';
  }

  @override
  String get toDropoff => 'To the customer';

  @override
  String toDropoffMinutes(int minutes) {
    return 'To the customer · $minutes min';
  }

  @override
  String get arrivedAtDestination => 'Arrived at destination';

  @override
  String get collectAtDeliveryTitle => 'Collect on delivery';

  @override
  String get collectAtDeliveryBody => 'Cash or Mobile Money, before handover.';

  @override
  String farFromAddress(String distance) {
    return 'You are $distance from the address: a delivery confirmed from here will be flagged to support.';
  }

  @override
  String get deliveryCodeLabel => 'Recipient code';

  @override
  String get deliveryCodeHint => 'received by SMS';

  @override
  String get noCodeLink => 'The customer has no code';

  @override
  String get hasCodeLink => 'The customer has a code';

  @override
  String get noCodeTitle => 'Delivery without a code';

  @override
  String get noCodeBody =>
      'The handover photo is required. Support calls the customer to confirm before closing the job.';

  @override
  String get receivedByLabel => 'Name of the person receiving';

  @override
  String get receivedByHint => 'E.g. their sister, the guard…';

  @override
  String get photoHandover => 'Photograph the handover';

  @override
  String get photoHandoverHint => 'Parcel and place visible';

  @override
  String photoHandoverTaken(String time) {
    return 'Handover photo · taken at $time';
  }

  @override
  String get confirmDelivery => 'Confirm delivery';

  @override
  String get deliveryQueuedTitle => 'Delivery saved';

  @override
  String get deliveryQueuedBody => 'No network: the delivery is sent automatically as soon as it is back.';

  @override
  String get awaitingSupportTitle => 'Delivery declared';

  @override
  String get awaitingSupportBody =>
      'Support calls the customer to confirm the handover. You will be notified once it is validated.';

  @override
  String get orderDeliveredNotice => 'Job delivered. Thank you!';

  @override
  String get backHome => 'Back to home';

  @override
  String get deliveryFailedTitle => 'Failed delivery';

  @override
  String get deliveryFailedBody => 'The failure and return screens (10 and 11) come in a later batch.';

  @override
  String get collectionTitle => 'Collection';

  @override
  String collectionSubtitle(String reference, String name) {
    return 'Job $reference · $name';
  }

  @override
  String get toCollectFromCustomer => 'To collect from the customer';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodMomo => 'Mobile Money';

  @override
  String get amountReceived => 'Amount received';

  @override
  String exactAmount(String amount) {
    return '$amount (exact)';
  }

  @override
  String get changeToGive => 'Change to give';

  @override
  String get customerOperator => 'Customer’s operator';

  @override
  String get customerMomoNumber => 'Customer’s Mobile Money number';

  @override
  String get momoHint => 'The customer approves the payment on their phone, then the job closes.';

  @override
  String get momoWaiting => 'Waiting for the customer to approve…';

  @override
  String get momoFailed => 'Payment not completed (refused, cancelled or expired). Resend the request or collect cash.';

  @override
  String get momoNoAnswer => 'Still no answer from the customer. You can resend the request.';

  @override
  String get momoNeedsNetwork => 'Mobile Money needs a network: collect cash or try again.';

  @override
  String get cashAfterCourse => 'Cash on hand after this job';

  @override
  String cashLimitReached(String limit) {
    return 'Above your limit ($limit): deposit cash at the Tara office to receive new jobs.';
  }

  @override
  String get confirmCollection => 'Confirm collection';

  @override
  String get sendPaymentRequest => 'Send payment request';

  @override
  String get resendPaymentRequest => 'Resend request';

  @override
  String get paymentRequestSent => 'Request sent to the customer';

  @override
  String get sosBadge => 'Safety';

  @override
  String get sosIdleTitle => 'Need help?';

  @override
  String get sosIdleBody =>
      'Hold the button for 3 seconds. The Tara team and your emergency contact receive your live location.';

  @override
  String get sosSentTitle => 'Alert sent';

  @override
  String get sosSentBody => 'Stay somewhere safe if you can. A Tara agent will call you back.';

  @override
  String get sosAcknowledgedBody =>
      'A Tara agent has taken your alert and is calling you back. Stay somewhere safe if you can.';

  @override
  String get sosPoliceCalledBody => 'The Tara team has alerted the police. Stay somewhere safe if you can.';

  @override
  String get sosPendingTitle => 'No internet';

  @override
  String get sosPendingBody =>
      'The alert will go out as soon as the network is back. Send it by SMS too: SMS often works without internet.';

  @override
  String get sosFailedTitle => 'Alert not sent';

  @override
  String get sosFailedBody => 'Call Tara or the police, or send the alert by SMS.';

  @override
  String get sosClosedBody => 'The Tara team closed your alert. Hold the button if you still need help.';

  @override
  String get sosPendingHint => 'Waiting';

  @override
  String get sosSendingHint => 'Sending…';

  @override
  String get sosYourPosition => 'Your location';

  @override
  String sosPositionCurrent(int meters) {
    return 'Current location · accuracy $meters m';
  }

  @override
  String sosPositionShared(int meters) {
    return 'Shared live with Tara · accuracy $meters m';
  }

  @override
  String get sosPositionSearching => 'Finding your location…';

  @override
  String get sosPositionUnknown => 'Location not found';

  @override
  String sosPlate(String plate) {
    return 'Motorbike $plate';
  }

  @override
  String get sosCallTara => 'Tara support';

  @override
  String sosCallPolice(String number) {
    return 'Police · $number';
  }

  @override
  String get sosAccident => 'Accident:';

  @override
  String sosFire(String number) {
    return 'Fire $number';
  }

  @override
  String sosMedical(String number) {
    return 'Ambulance $number';
  }

  @override
  String get sosSendSms => 'Send the alert by SMS';

  @override
  String get sosCancel => 'Cancel the alert';

  @override
  String get sosCancelNeedsNetwork => 'Cannot cancel without a network. Call Tara to confirm.';

  @override
  String sosSmsBody(String map) {
    return 'SOS Tara: I need help. Location: $map';
  }

  @override
  String get sosSmsNoPosition => 'SOS Tara: I need help. Location unknown.';

  @override
  String sosSmsCourse(String reference) {
    return ' Job $reference.';
  }

  @override
  String get sosPositionCurrentPlain => 'Current location';

  @override
  String get sosPositionSharedPlain => 'Shared live with Tara';
}

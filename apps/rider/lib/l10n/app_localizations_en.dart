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
  String get riderSpace => 'TARA RIDER · DOUALA';

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
  String get legalPrefix => 'New account: you will read and accept the ';

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
  String get guarantor => 'Guarantor (optional)';

  @override
  String get guarantorHelp => 'A trusted person who vouches for you. You can leave this section empty.';

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
  String bonusIncluded(String details) {
    return 'includes $details';
  }

  @override
  String approachBonus(String amount) {
    return 'pickup distance bonus $amount';
  }

  @override
  String boostBonus(String amount) {
    return 'boost $amount';
  }

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
  String get packageBulky => 'Bulky item';

  @override
  String get comeWithHelper => 'Come with a helper';

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
  String newTour(int count) {
    return 'Round · $count parcels';
  }

  @override
  String nextStopTitle(int stop, int total) {
    return 'Stop $stop of $total';
  }

  @override
  String get nextStopGo => 'Head to this customer';

  @override
  String tourProgress(int stop, int total, String earned) {
    return 'Round · stop $stop of $total · $earned earned';
  }

  @override
  String tourToCollect(int checked, int total) {
    return 'PARCELS TO COLLECT · $checked OF $total CHECKED';
  }

  @override
  String photoTourHint(int count) {
    return 'All $count parcels together, numbers visible';
  }

  @override
  String tourStops(int count) {
    return '$count stops, in order';
  }

  @override
  String parcelNumberShort(int number) {
    return 'No. $number';
  }

  @override
  String get arrivedAction => 'I\'ve arrived';

  @override
  String get senderAbsentAction => 'The sender is not coming';

  @override
  String senderAbsentLater(int minutes, String share) {
    return 'Not coming? In $minutes min you can leave: $share for you.';
  }

  @override
  String senderAbsentCallFirst(int count) {
    return 'First call the sender ($count more call(s)) with the call button.';
  }

  @override
  String senderAbsentConfirm(String fee, String share) {
    return 'The job will be cancelled. The sender will pay $fee, $share of it for you. Tap again to confirm.';
  }

  @override
  String get senderAbsentNotice => 'Job cancelled: your waiting time is paid.';

  @override
  String get arrivedSending => 'Sending…';

  @override
  String waitingRule(int free, String fee, int step, String share, String max) {
    return 'Once there, tap “I\'ve arrived”: the sender is told. Waiting is free for $free min, then $fee per $step min ($max at most), $share of it for you.';
  }

  @override
  String waitingFree(int minutes, int left) {
    return 'You have been waiting $minutes min · free for $left more min.';
  }

  @override
  String waitingPaid(int minutes, String fee, String share) {
    return 'You have been waiting $minutes min · $fee waiting fee for the sender, $share of it for you.';
  }

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
  String get photoParcelHint => 'Whole parcel, clearly visible';

  @override
  String photoParcelTaken(String time) {
    return 'Parcel photo · taken at $time';
  }

  @override
  String get retakePhoto => 'Retake';

  @override
  String get parcelCollected => 'Parcel collected';

  @override
  String get parcelNotConforming => 'Parcel not as declared?';

  @override
  String get bulkyNotice => 'Bulky item: check that it fits your vehicle before loading it.';

  @override
  String get bulkyWithHelpNotice => 'Bulky item, loading help paid by the sender: come with a helper.';

  @override
  String get refusalTitle => 'Parcel not as declared';

  @override
  String get refusalBody =>
      'Do not take a parcel that is too big, too heavy, different from what was declared, or forbidden. Report it here before entering the code.';

  @override
  String get refusalReasonLabel => 'Why?';

  @override
  String get refusalTooBig => 'Too big for my vehicle';

  @override
  String get refusalTooHeavy => 'Too heavy';

  @override
  String get refusalNotAsDeclared => 'Not what was declared';

  @override
  String get refusalForbidden => 'Forbidden item';

  @override
  String get refusalNoteLabel => 'Details (optional)';

  @override
  String get refusalNoteHint => 'E.g. 3-door wardrobe instead of a box';

  @override
  String get refusalPhotoHint => 'Whole parcel visible: it is the proof';

  @override
  String get refusalNotice =>
      'The job will be cancelled and your trip will be paid. The sender sees the reason and the photo. A refusal without a valid reason is reported to the team.';

  @override
  String get refusalConfirm => 'Refuse the parcel';

  @override
  String get parcelRefusedNotice => 'Parcel refused. Your trip is paid.';

  @override
  String get refusalQueuedTitle => 'Refusal saved';

  @override
  String get refusalQueuedBody => 'It will be sent as soon as the network is back. You can leave.';

  @override
  String get queuedRefuseParcel => 'Non-conforming parcel refused';

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

  @override
  String get failureTitle => 'Delivery impossible';

  @override
  String get failureReasonLabel => 'Reason';

  @override
  String get reasonRecipientAbsent => 'Customer absent';

  @override
  String get reasonRecipientUnreachable => 'Unreachable';

  @override
  String get reasonAddressNotFound => 'Address not found';

  @override
  String get reasonRefused => 'Parcel refused';

  @override
  String get reasonPaymentRefused => 'Refused to pay';

  @override
  String get reasonOther => 'Other reason';

  @override
  String get failureNoteLabel => 'Describe the reason';

  @override
  String get failureNoteHint => 'E.g. gate locked, dangerous dog';

  @override
  String get callsTitle => 'Calls to the recipient';

  @override
  String callsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
      zero: 'No call',
    );
    return '$_temp0';
  }

  @override
  String get callMade => 'Call made';

  @override
  String callMeta(String time, String duration) {
    return '$time · $duration';
  }

  @override
  String get callsNotRequired => 'No call required for this reason.';

  @override
  String get callsDone => 'Enough calls.';

  @override
  String callsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more calls to make.',
      one: '1 more call to make.',
    );
    return '$_temp0';
  }

  @override
  String callsMissingAt(String time) {
    return '1 more call, from $time.';
  }

  @override
  String get callRecipient => 'Call';

  @override
  String get callAgain => 'Call again';

  @override
  String get photoPlace => 'Photo of the place · required';

  @override
  String get photoPlaceHint => 'Door, gate or shopfront visible';

  @override
  String photoPlaceTaken(String time) {
    return 'Photo of the place · taken at $time';
  }

  @override
  String failureNotice(int minutes) {
    return 'The sender is told right away and chooses: try again or return. Without an answer within $minutes min, you bring the parcel back.';
  }

  @override
  String get validateFailure => 'Confirm the failure';

  @override
  String get cantDeliver => 'Can\'t deliver?';

  @override
  String get failureWaitingTitle => 'Failure recorded';

  @override
  String failureWaitingBody(String time) {
    return 'The sender chooses: try again or return. Without an answer, the return is decided at $time. Keep the parcel with you.';
  }

  @override
  String get failureWaitingBodyQueued =>
      'The failure will be sent as soon as the network is back. Keep the parcel with you.';

  @override
  String get retryTitle => 'New attempt';

  @override
  String get retryBody => 'The sender asks for a new attempt. Head back to the recipient.';

  @override
  String get retryAction => 'Head back to the recipient';

  @override
  String get returnTitle => 'Parcel return';

  @override
  String returnMinutes(int minutes) {
    return 'Parcel return · $minutes min';
  }

  @override
  String failureChip(String reason) {
    return 'Failed · $reason';
  }

  @override
  String get returnTo => 'Bring the parcel back to';

  @override
  String get returnStepJoin => 'Get to the seller';

  @override
  String get returnStepCode => 'Enter the seller\'s return code';

  @override
  String get returnStepPhoto => 'Photograph the returned parcel';

  @override
  String get stepInProgress => 'In progress';

  @override
  String get atSender => 'I\'m at the seller\'s';

  @override
  String get returnCodeLabel => 'Return code';

  @override
  String get returnCodeHint => 'received by the seller by SMS';

  @override
  String get photoReturned => 'Photograph the returned parcel';

  @override
  String get photoReturnedHint => 'Parcel in the seller\'s hands';

  @override
  String photoReturnedTaken(String time) {
    return 'Return photo · taken at $time';
  }

  @override
  String get parcelReturned => 'Parcel returned';

  @override
  String get returnQueuedTitle => 'Return recorded';

  @override
  String get returnQueuedBody => 'It will be sent as soon as the network is back.';

  @override
  String get orderReturnedNotice => 'Parcel returned to the seller: job done.';

  @override
  String get earningsToday => 'Today’s earnings';

  @override
  String get earningsWeek => 'This week\'s earnings';

  @override
  String get earningsMonth => 'This month\'s earnings';

  @override
  String coursesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
      zero: 'No job',
    );
    return '$_temp0';
  }

  @override
  String get weekdaysShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get todayShort => 'Today';

  @override
  String weekShort(int number) {
    return 'W$number';
  }

  @override
  String hourShort(int hour) {
    return '${hour}h';
  }

  @override
  String chartSemantics(String caption, String values) {
    return '$caption: $values';
  }

  @override
  String get cashToDeposit => 'Cash to pay back to Tara';

  @override
  String get depositAction => 'Pay back';

  @override
  String get lastCourses => 'Latest jobs';

  @override
  String get seeAll => 'See all';

  @override
  String get seeLess => 'See less';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusReturned => 'Returned to seller';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String cashCollectedAmount(String amount) {
    return '$amount collected';
  }

  @override
  String get noCoursesYet => 'No finished job yet.';

  @override
  String get activityError => 'Couldn\'t load your activity.';

  @override
  String get depositTitle => 'Pay back cash';

  @override
  String depositBody(String amount) {
    return 'A payment request of $amount goes to your phone. Approve it with your Mobile Money PIN.';
  }

  @override
  String get depositOffice => 'You can also bring the cash to the Tara office.';

  @override
  String get depositNumber => 'Your Mobile Money number';

  @override
  String get depositSend => 'Send the request';

  @override
  String get depositWaiting => 'Approve the request on your phone…';

  @override
  String depositDone(String amount) {
    return '$amount paid back to Tara.';
  }

  @override
  String get depositFailed => 'Payment not completed. Try again or pay at the Tara office.';

  @override
  String get depositOperator => 'Operator';

  @override
  String cashDueAt(String time) {
    return 'Pay back before $time';
  }

  @override
  String cashDueTomorrow(String time) {
    return 'Pay back before tomorrow $time';
  }

  @override
  String get cashOverdueNotice => 'Overdue: no more jobs until you pay back.';

  @override
  String get blockerCashOverdue => 'Cash not paid back within 24 h: pay it back (Activity tab) to receive jobs.';

  @override
  String get blockerSuspended => 'Account suspended: contact Tara.';

  @override
  String get blockerPending => 'Account being validated.';

  @override
  String get pendingActionsTitle => 'Pending actions';

  @override
  String get autoSend => 'Sent automatically';

  @override
  String get queuedPickup => 'Pickup';

  @override
  String get queuedDepart => 'Leaving for the customer';

  @override
  String get queuedCollect => 'Cash collection';

  @override
  String get queuedDeliver => 'Delivery confirmed';

  @override
  String get queuedFail => 'Failed delivery';

  @override
  String get queuedRetry => 'New attempt';

  @override
  String get queuedReturn => 'Return to seller';

  @override
  String get detailCodePhoto => 'code + photo';

  @override
  String get detailNoCodePhoto => 'no code + photo';

  @override
  String detailPhotoSize(String size) {
    return 'photo $size MB';
  }

  @override
  String get statusWaiting => 'Waiting';

  @override
  String get statusSending => 'Sending…';

  @override
  String get statusRefused => 'Refused';

  @override
  String get offlineNote => 'You can keep going: the route and codes stay available offline.';

  @override
  String get retryNow => 'Try again now';

  @override
  String get retrying => 'Trying to send…';

  @override
  String get stillOffline => 'Still offline · Try again';

  @override
  String get continueCourse => 'Continue the job';

  @override
  String get allSent => 'Everything is sent.';

  @override
  String get refusedBannerTitle => 'Action refused';

  @override
  String refusedBannerDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions to check',
      one: '1 action to check',
    );
    return '$_temp0';
  }

  @override
  String get refusedHelp => 'Refused by the server. Fix it from the job, or call support before removing it.';

  @override
  String get removeAction => 'Remove the action';

  @override
  String get confirmRemoveAction => 'Confirm removal';

  @override
  String get offlineNoPending => 'Your actions are kept on the phone';

  @override
  String silentWithdrawIn(int minutes) {
    return 'Parcel not picked up yet: the job will be withdrawn in $minutes min if the network does not come back';
  }

  @override
  String get silentWithdrawNow => 'Offline for too long: the job may have been given to another rider';

  @override
  String get balanceAvailable => 'Available balance';

  @override
  String balanceReserved(String amount) {
    return '$amount set aside for your current jobs';
  }

  @override
  String get balanceExplain => 'Covers the money you collect on your jobs';

  @override
  String get topUpAction => 'Top up';

  @override
  String get topUpTitle => 'Top up my balance';

  @override
  String get topUpAmount => 'Amount';

  @override
  String get topUpOther => 'Other amount (F)';

  @override
  String get topUpOtherHint => 'e.g. 15000';

  @override
  String topUpBody(String amount) {
    return 'A payment request for $amount is sent to your phone. Tara pays the Mobile Money fees: your balance receives $amount.';
  }

  @override
  String topUpWithdrawRule(String min) {
    return 'This balance covers the cash you collect on your jobs. It can be withdrawn to Mobile Money from $min.';
  }

  @override
  String get topUpOffice => 'You can also top up with cash at the Tara office.';

  @override
  String topUpDone(String amount) {
    return '$amount added to your balance.';
  }

  @override
  String get topUpFailed => 'Payment did not go through. Try again or top up at the Tara office.';

  @override
  String topUpRange(String min, String max) {
    return 'Amount between $min and $max.';
  }

  @override
  String get takenFromBalance => 'Taken from your balance (already set aside)';

  @override
  String get balanceShort => 'Balance';

  @override
  String get myDocuments => 'My documents';

  @override
  String get myDocumentsBody => 'Send a rejected or expired document again here; the Tara team checks it again.';

  @override
  String docsToFix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents to send again',
      one: '1 document to send again',
    );
    return '$_temp0';
  }

  @override
  String get docsToFixHint => 'Without it, you can no longer receive jobs.';

  @override
  String docsInReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents being checked',
      one: '1 document being checked',
    );
    return '$_temp0';
  }

  @override
  String get docsAllApproved => 'All your documents are approved';

  @override
  String get emergencyContactTitle => 'Emergency contact';

  @override
  String get emergencyNone => 'No contact';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get removeContact => 'Remove this contact';

  @override
  String get displaySection => 'Display';

  @override
  String get themeLabel => 'Theme';

  @override
  String get optionAuto => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageLabel => 'Language';

  @override
  String get effectsLabel => 'Animations';

  @override
  String get effectsFull => 'Full';

  @override
  String get effectsReduced => 'Reduced';

  @override
  String get effectsHint => 'Reduced: fewer effects, smoother on a modest phone.';

  @override
  String get glassLabel => 'Bar transparency';

  @override
  String get glassClear => 'Glass';

  @override
  String get glassBalanced => 'Balanced';

  @override
  String get glassOpaque => 'Solid';

  @override
  String get glassHint => 'Changes how see-through the bottom bar and the buttons at the bottom of the screen are.';

  @override
  String get effectsAutoReduced => 'Reduced automatically on this phone.';

  @override
  String get helpSection => 'Help';

  @override
  String get supportTara => 'Tara support';

  @override
  String get logoutConfirm => 'You will not receive jobs on this phone until you sign in again.';

  @override
  String get logoutBlockedCourse => 'Finish your job before signing out.';

  @override
  String get logoutBlockedPending => 'Some actions are waiting for the network and would be lost. Reconnect first.';

  @override
  String appVersion(String version) {
    return 'Tara Rider · version $version';
  }

  @override
  String get accountActive => 'Account active';

  @override
  String get accountPending => 'Application being checked';

  @override
  String get accountSuspended => 'Account suspended';

  @override
  String get accountRejected => 'Application rejected';

  @override
  String get profileError => 'Could not load your profile.';

  @override
  String get slideToAccept => 'Slide to accept';

  @override
  String get soundsLabel => 'Sounds';

  @override
  String get soundsHint => 'New job, parcel delivered, cash collected… Your phone’s silent mode is respected.';

  @override
  String milestoneTitle(int count) {
    return '$count deliveries today!';
  }

  @override
  String get milestoneBody => 'Great work, keep it up.';

  @override
  String rateSenderTitle(String name) {
    return 'Rate $name';
  }

  @override
  String get rateSenderBody => 'Sender of your last delivery';

  @override
  String get rateSenderThanks => 'Thanks! Your rating helps Tara pick its customers well.';

  @override
  String get senderFallback => 'the sender';

  @override
  String starsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count stars', one: '1 star');
    return '$_temp0';
  }

  @override
  String get returnFeesTitle => 'Return fees to collect';

  @override
  String returnFeesBody(String name, String amount) {
    return '$name pays $amount before getting the parcel back: what their Tara balance doesn’t cover.';
  }

  @override
  String returnFeesCash(String amount) {
    return 'Cash received · $amount';
  }

  @override
  String get returnFeesCashNote => 'You keep the cash: the amount is taken from your balance.';

  @override
  String get returnFeesMomo => 'Ask by Mobile Money';

  @override
  String get returnFeesSend => 'Send the request';

  @override
  String get returnFeesWaiting => 'Request sent: the sender approves it on their phone.';

  @override
  String get returnFeesPaid => 'Return fees paid: you can hand the parcel back.';

  @override
  String get returnFeesChecking => 'Checking return fees…';

  @override
  String get returnFeesOffline => 'A connection is needed to check the return fees.';

  @override
  String get termsTitle => 'Rider terms';

  @override
  String get termsUpdateTitle => 'Our terms have changed';

  @override
  String get termsSignupIntro =>
      'Before creating your account, read the rider terms and the privacy policy to the end. They explain your status, your earnings, cash collection and what we do with your data.';

  @override
  String get termsUpdateIntro =>
      'Read the new version to the end, then accept it. Until you accept, you can finish your current delivery but will not receive new ones.';

  @override
  String get termsLater => 'Later';

  @override
  String get termsEnd => 'You have reached the end of the texts.';

  @override
  String get termsScrollFirst => 'Scroll to the end of the texts to be able to accept them.';

  @override
  String get termsCheckPrefix => 'I have read and accept the ';

  @override
  String termsCheckTerms(String version) {
    return 'rider terms (version $version)';
  }

  @override
  String get termsCheckAnd => ' and the ';

  @override
  String get termsCheckPrivacy => 'privacy policy';

  @override
  String get termsCreateAccount => 'Accept and create my account';

  @override
  String get termsAcceptUpdate => 'I accept the new version';

  @override
  String termsAcceptedOn(String version, String date) {
    return 'Version $version accepted on $date';
  }

  @override
  String termsVersionLine(String version) {
    return 'Version $version';
  }

  @override
  String get termsSection => 'Terms and privacy';

  @override
  String get termsPrivacyTitle => 'Privacy policy';

  @override
  String get termsToSign => 'New version to read and accept';

  @override
  String get blockerTerms => 'Our terms have changed: read and accept them to receive deliveries.';

  @override
  String get readAndSign => 'Read and accept';

  @override
  String get addressPhoto => 'See the entrance';

  @override
  String get addressVoice => 'Play the note';

  @override
  String get addressVoiceStop => 'Stop the note';

  @override
  String get addressMediaFailed => 'File unavailable right now: try again.';

  @override
  String addressPhotoTitle(String name) {
    return 'Entrance · $name';
  }

  @override
  String get toCollectByMomo => 'To request by Mobile Money';

  @override
  String momoFeeIncluded(String amount, String fee) {
    return '$amount for the delivery and parcel, plus $fee Mobile Money fee paid by the customer.';
  }

  @override
  String withdrawalRule(String amount, String rate) {
    return 'Free withdrawal from $amount; below that, a $rate Mobile Money fee is deducted.';
  }

  @override
  String get supportTitle => 'Help and customer service';

  @override
  String get supportIntro =>
      'A problem with a job, your earnings or the app? Write to us: the Tara team answers here and you are notified of its reply.';

  @override
  String get supportNewRequest => 'New request';

  @override
  String get supportEmpty => 'No requests yet.';

  @override
  String supportCallUs(String phone) {
    return 'Urgent? Call $phone';
  }

  @override
  String get supportCategoryPayment => 'Earnings, balance or withdrawal';

  @override
  String get supportCategoryLostParcel => 'Lost parcel';

  @override
  String get supportCategoryDamagedParcel => 'Damaged parcel';

  @override
  String get supportCategoryAppBug => 'Problem in the app';

  @override
  String get supportCategoryOther => 'Other';

  @override
  String get supportStatusOpen => 'Sent';

  @override
  String get supportStatusInProgress => 'In progress';

  @override
  String get supportStatusResolved => 'Resolved';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportNewTitle => 'New request';

  @override
  String get supportReasonLabel => 'Reason';

  @override
  String get supportSubjectLabel => 'In a few words';

  @override
  String get supportSubjectHint => 'E.g. withdrawal not received';

  @override
  String get supportMessageLabel => 'Tell us more';

  @override
  String get supportMessageHint => 'What happened, and the job concerned if any.';

  @override
  String supportOrderLine(String reference) {
    return 'Job $reference';
  }

  @override
  String get supportSend => 'Send the request';

  @override
  String get supportReplyHint => 'Your reply…';

  @override
  String get supportReplySend => 'Send';

  @override
  String get supportClosedNote => 'This request is closed. Open a new request if needed.';

  @override
  String get supportFromTara => 'Tara customer service';

  @override
  String get supportNewAnswer => 'Reply';

  @override
  String get supportWaitingNote => 'The Tara team answers here; you will be notified.';

  @override
  String get supportMenuRow => 'Write to customer service';

  @override
  String get supportMenuRowSubtitle => 'Your requests and Tara’s replies';

  @override
  String get withdrawAction => 'Withdraw';

  @override
  String get withdrawTitle => 'Withdraw to Mobile Money';

  @override
  String withdrawAll(String amount) {
    return 'All · $amount';
  }

  @override
  String get withdrawOtherHint => 'E.g. 5000';

  @override
  String withdrawTo(String phone) {
    return 'Sent to your number $phone, the only one allowed for a withdrawal.';
  }

  @override
  String withdrawFeeFull(String fee) {
    return 'Mobile Money fee: $fee.';
  }

  @override
  String withdrawFreeFrom(String amount) {
    return 'Free withdrawal from $amount.';
  }

  @override
  String get withdrawFree => 'Free withdrawal: Tara pays the Mobile Money fee.';

  @override
  String get withdrawReceive => 'You receive';

  @override
  String withdrawConfirm(String amount) {
    return 'Receive $amount';
  }

  @override
  String withdrawBelowMinimum(String min, String missing) {
    return 'Withdrawals to Mobile Money start at $min. You need $missing more: your balance stays safe with Tara until then.';
  }

  @override
  String withdrawRange(String min, String max) {
    return 'Between $min and $max, or the whole balance.';
  }

  @override
  String withdrawProcessing(String amount) {
    return 'Withdrawal requested: $amount will reach your Mobile Money within a few minutes. A notification will let you know.';
  }

  @override
  String withdrawApproval(String amount) {
    return 'Large amount: the Tara team approves the $amount withdrawal before sending it. A notification will let you know.';
  }

  @override
  String withdrawSent(String amount) {
    return '$amount sent to your Mobile Money.';
  }

  @override
  String get withdrawFailed => 'The withdrawal did not go through: the money stays in your balance. Try again later.';

  @override
  String withdrawOpen(String amount) {
    return '$amount withdrawal in progress';
  }

  @override
  String get accountDataSection => 'My account and data';

  @override
  String get exportDataRow => 'Download my data';

  @override
  String get exportDataRowSubtitle => 'A copy of everything Tara keeps about you';

  @override
  String get exportDataShare => 'My Tara data';

  @override
  String get closeAccountRow => 'Close my account';

  @override
  String get closeAccountRowSubtitle => 'Request to the Tara team';

  @override
  String get closeAccountTitle => 'Close my account';

  @override
  String get closeAccountBody =>
      'The Tara team closes the account after checking: no job in progress, nothing owed to Tara and no money left in your balance.';

  @override
  String get closeAccountErased =>
      'Your ID documents, guarantor and emergency contact are then erased. Your past jobs remain, without your name, for the accounts.';

  @override
  String closeAccountSmallBalance(String amount, String min) {
    return 'You still have $amount, less than the smallest Mobile Money withdrawal ($min): call Tara customer service to get it back before closing your account.';
  }

  @override
  String closeAccountBalance(String amount) {
    return 'You still have $amount: withdraw it to your Mobile Money first (Activity tab).';
  }

  @override
  String closeAccountDebt(String amount) {
    return 'You owe Tara $amount: top up your balance first (Activity tab).';
  }

  @override
  String get closeAccountPayout => 'A withdrawal to your Mobile Money is in progress: wait for it to arrive.';

  @override
  String get closeAccountCourse => 'Finish your job before asking to close your account.';

  @override
  String get closeAccountSend => 'Ask to close my account';

  @override
  String get closeAccountSent => 'Request sent. The Tara team answers in “Write to customer service”.';

  @override
  String get closeAccountTicketSubject => 'Closing my rider account';

  @override
  String get closeAccountTicketMessage => 'I would like to close my Tara rider account and erase my data.';

  @override
  String get reasonDamaged => 'Damaged parcel, refused';

  @override
  String get photoDamaged => 'Photo of the damaged parcel · required';

  @override
  String get photoDamagedHint => 'The damage clearly visible';

  @override
  String get damagedNotice =>
      'The recipient refuses a damaged parcel: photograph the damage and describe it. The Tara team opens a claim for the sender; bring the parcel back as a return.';

  @override
  String get damagedNoteHint => 'E.g. crushed box, broken bottle';

  @override
  String get pinCreateTitle => 'Choose your secret PIN';

  @override
  String get pinCreateBody =>
      '4 digits, like for Orange Money or MoMo. It protects your balance and withdrawals. Never share it, not even with Tara.';

  @override
  String get pinConfirmTitle => 'Confirm your secret PIN';

  @override
  String get pinMismatch => 'The two PINs are different. Start again.';

  @override
  String get pinEnterTitle => 'Secret PIN';

  @override
  String get pinCurrentTitle => 'Your current secret PIN';

  @override
  String get pinNewTitle => 'New secret PIN';

  @override
  String get pinForgot => 'Forgot your PIN?';

  @override
  String get pinUseBiometrics => 'Also use my fingerprint';

  @override
  String get pinBiometricButton => 'Use my fingerprint';

  @override
  String get pinBiometricTitle => 'Confirm with your fingerprint';

  @override
  String get pinDelete => 'Delete';

  @override
  String pinDigitsEntered(int count) {
    return '$count digit(s) out of 4';
  }

  @override
  String get pinLockedTitle => 'Secret PIN blocked';

  @override
  String get pinLockedBody =>
      'After 5 errors, your secret PIN is blocked. Get a code on your number to choose a new one.';

  @override
  String get pinResetBody => 'Get a code on your number to choose a new secret PIN.';

  @override
  String get pinSendCode => 'Get a code';

  @override
  String get pinCodeSentSms => 'Enter the code sent by SMS.';

  @override
  String get pinCodeSentWhatsApp => 'Enter the code sent on WhatsApp.';

  @override
  String get codeBySms => 'Get it by SMS';

  @override
  String codeSentWhatsAppTo(String phone) {
    return 'Code sent on WhatsApp to $phone';
  }

  @override
  String get pinSaved => 'Secret PIN saved.';

  @override
  String get balanceShow => 'Show balance';

  @override
  String get balanceHide => 'Hide balance';

  @override
  String get pinReasonBalance => 'To see your balance';

  @override
  String pinReasonWithdraw(String amount) {
    return 'To withdraw $amount';
  }

  @override
  String get pinRowTitle => 'Secret PIN';

  @override
  String get pinRowSet => 'Change my secret PIN';

  @override
  String get pinRowNotSet => 'Choose my secret PIN';

  @override
  String get biometricRowTitle => 'Fingerprint';

  @override
  String get biometricRowBody => 'Confirm with your fingerprint instead of the PIN';

  @override
  String get securitySection => 'Security';

  @override
  String get parcelToCollect => 'Parcel to collect';

  @override
  String get parcelToDeliver => 'Parcel to hand over';

  @override
  String parcelNumber(int n) {
    return 'no. $n';
  }

  @override
  String parcelFor(String name, String place) {
    return 'For $name · $place';
  }

  @override
  String photoParcelHintNumber(int n) {
    return 'Number $n clearly visible';
  }

  @override
  String get tabCourse => 'Ride';

  @override
  String get tabEarnings => 'Earnings';

  @override
  String get onlineTodayWord => 'today';

  @override
  String get prepaidTitle => 'Prepaid balance';

  @override
  String get prepaidCovers => 'Covers the cash you collect';

  @override
  String onlineSince(String time) {
    return 'Online · $time';
  }

  @override
  String get zoneForbiddenLegend => 'No-go zone: no rides';

  @override
  String todayTotal(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'rides', one: 'ride');
    return '$amount · $count $_temp0';
  }

  @override
  String get myEarnings => 'My earnings';

  @override
  String get thisWeek => 'This week';

  @override
  String get todaySuffix => 'today';

  @override
  String get dayNotYet => 'to come';

  @override
  String get dayNotYetLabel => 'not ridden yet';

  @override
  String get weekOnline => 'Online';

  @override
  String get weekRides => 'Rides';

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String get themeAuto => 'Automatic';

  @override
  String get effectsAll => 'All';

  @override
  String get myDocumentsRowSubtitle => 'A refused or expired document is sent again here';

  @override
  String termsRowAccepted(String version, String date) {
    return 'Version $version accepted on $date';
  }

  @override
  String get termsRowToSign => 'New version to accept';

  @override
  String get securityRow => 'Secret code and fingerprint';

  @override
  String get securityRowSubtitle => 'To see the balance and withdraw';

  @override
  String get displayMoreRow => 'Language and sounds';

  @override
  String secondsToAccept(int seconds) {
    return '$seconds s to accept';
  }

  @override
  String stopPickup(String name) {
    return 'Pickup · $name';
  }

  @override
  String stopDropoff(String place) {
    return 'Delivery · $place';
  }

  @override
  String approachFromYou(String distance) {
    return '$distance from you';
  }

  @override
  String toCollectLower(String amount) {
    return 'to collect $amount';
  }

  @override
  String get alreadyPaid => 'already paid';

  @override
  String toCollectChip(String amount) {
    return 'To collect $amount';
  }

  @override
  String tourOnePickup(int count) {
    return '$count parcels · one pickup';
  }

  @override
  String tripSummary(String distance, int minutes) {
    return '$distance · ~$minutes min';
  }

  @override
  String tourSummary(String distance, int count) {
    return '$distance · $count stops';
  }

  @override
  String pinPickup(String name) {
    return 'A · $name';
  }

  @override
  String pinDropoff(String place) {
    return 'B · $place';
  }

  @override
  String get missingPhoto => 'the photo';

  @override
  String get missingCode => 'the code';

  @override
  String get missingParcels => 'the parcels to tick';

  @override
  String missingItems(String items) {
    return 'Missing: $items.';
  }

  @override
  String get slideParcelCollected => 'Slide · Parcel collected';

  @override
  String get parcelNonConforming => 'Parcel not as described';

  @override
  String waitingSince(int minutes) {
    return 'You have been waiting $minutes min · ';
  }

  @override
  String waitingFreeLeft(int left) {
    return 'free for $left more min';
  }

  @override
  String waitingThen(String fee, int step) {
    return '. Then $fee per $step min for the sender.';
  }

  @override
  String get slideConfirmDelivery => 'Slide · Confirm delivery';

  @override
  String get cantDeliverShort => 'Can’t deliver';

  @override
  String distanceAway(String distance) {
    return '$distance away';
  }

  @override
  String towards(String place) {
    return 'Towards $place';
  }

  @override
  String courseReference(String reference) {
    return 'Ride $reference';
  }

  @override
  String toCollectFrom(String name) {
    return 'To collect from $name';
  }

  @override
  String get exactShort => 'Exact';

  @override
  String cashKeptFromBalance(String amount) {
    return 'You keep the cash: $amount is taken from your prepaid balance, where it was already set aside.';
  }

  @override
  String get slideConfirmCollection => 'Slide · Confirm collection';

  @override
  String deliveredAtLabel(String reference, String time) {
    return '$reference · delivered at $time';
  }

  @override
  String todayEarningsPill(String amount) {
    return 'Today · $amount';
  }

  @override
  String rideOfDay(int count) {
    return 'Ride no. $count today';
  }

  @override
  String rideOfDayBravo(int count, String name) {
    return 'Ride no. $count today · well done $name';
  }

  @override
  String get addedToEarnings => 'Added to today’s earnings';

  @override
  String dailyGoal(int count) {
    return 'Today’s goal: $count rides';
  }

  @override
  String ridesToNextCelebration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more rides to the next celebration.',
      one: '1 more ride to the next celebration.',
    );
    return '$_temp0';
  }

  @override
  String get continueOnline => 'Continue · stay online';

  @override
  String get cashToDepositKicker => 'Cash to pay in';

  @override
  String get prepaidCoversMoney => 'It covers the money you collect';

  @override
  String get depositSubtitle => 'Cash collected before the prepaid balance';

  @override
  String get withdrawSubtitle => 'To your registered number';

  @override
  String get sosSubtitle => 'Your emergency contact is told too';

  @override
  String get onboardingProfileSubtitle => 'A few details about you';

  @override
  String get myAccount => 'My account';

  @override
  String get emergencyContactSubtitle => 'Someone close, to be told if needed';
}

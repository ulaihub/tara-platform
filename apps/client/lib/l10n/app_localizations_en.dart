// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get addLegalIds => 'Add RCCM and NIU (optional)';

  @override
  String get back => 'Back';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryElectronics => 'Electronics';

  @override
  String get categoryFashion => 'Fashion';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryHome => 'Home';

  @override
  String get categoryOther => 'Other';

  @override
  String get change => 'Change';

  @override
  String codeSentTo(String phone) {
    return 'Sent by SMS to $phone';
  }

  @override
  String get codeTitle => 'Enter the code you received';

  @override
  String get continueLabel => 'Continue';

  @override
  String countryCodeLabel(String code) {
    return 'Country code $code';
  }

  @override
  String digitLabel(int index) {
    return 'Digit $index';
  }

  @override
  String get firstName => 'First name';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get getCode => 'Get the code';

  @override
  String get haveReferral => 'I have a referral code';

  @override
  String get kindPerson => 'For myself';

  @override
  String get kindPersonHelp => 'You can switch to shop mode later, from your profile.';

  @override
  String get kindQuestion => 'You send parcels…';

  @override
  String get kindShop => 'For my shop';

  @override
  String get kindShopHelp => 'Money collected on delivery is paid out to you by Mobile Money.';

  @override
  String get lastName => 'Last name';

  @override
  String get legalAnd => ' and the ';

  @override
  String get legalPrefix => 'New account: you will read and accept the ';

  @override
  String get logout => 'Sign out';

  @override
  String get networkError => 'No internet connection. Check the network and try again.';

  @override
  String get niu => 'NIU';

  @override
  String get niuHint => 'e.g. M012345678901A';

  @override
  String get noSms => 'No SMS? Contact support';

  @override
  String get payoutHelp => 'Mobile Money number that receives your collected sales.';

  @override
  String get payoutNumber => 'Mobile Money number';

  @override
  String get payoutTitle => 'Payouts';

  @override
  String get phoneHelp => 'You will receive a free text message. No email needed.';

  @override
  String get phoneHint => '6XX XX XX XX';

  @override
  String get phoneInvalid => '9-digit Cameroonian mobile number starting with 6.';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get privacy => 'privacy policy';

  @override
  String get rccm => 'RCCM';

  @override
  String get rccmHint => 'e.g. RC/DLA/2024/B/1234';

  @override
  String get referralHint => 'e.g. TARA-7KQ2PM';

  @override
  String get referralLabel => 'Referral code';

  @override
  String get requiredField => 'Required';

  @override
  String get resend => 'Resend';

  @override
  String resendIn(String time) {
    return 'Resend the code in $time';
  }

  @override
  String get resendNow => 'Didn’t get anything?';

  @override
  String get retry => 'Retry';

  @override
  String get senderSpace => 'Send your parcels';

  @override
  String get shopCategory => 'Category (optional)';

  @override
  String get shopName => 'Shop name';

  @override
  String get shopNameHint => 'e.g. Awa Fashion';

  @override
  String get signInBody => 'Sign in with your number, or create your account. We will text you a code.';

  @override
  String get signInTitle => 'Your parcels delivered in Douala';

  @override
  String get terms => 'terms of use';

  @override
  String get validate => 'Confirm';

  @override
  String get welcomeBody => 'Your name appears in the messages sent to your recipients.';

  @override
  String get welcomeTitle => 'Welcome to Tara';

  @override
  String get appTitle => 'Tara';

  @override
  String get goodMorning => 'Good morning,';

  @override
  String get goodEvening => 'Good evening,';

  @override
  String get tabHome => 'Home';

  @override
  String get tabOrders => 'Orders';

  @override
  String get tabProfile => 'Profile';

  @override
  String get sendTitle => 'Send a parcel';

  @override
  String get sendBody => 'A rider picks it up and delivers it in Douala, with live tracking.';

  @override
  String get newDelivery => 'New delivery';

  @override
  String get askAddress => 'Ask the recipient for their address';

  @override
  String get shopBalance => 'Shop sales';

  @override
  String get shopBalanceDaily => 'To receive · paid to your Mobile Money every night';

  @override
  String get shopBalanceOnDemand => 'To receive · paid out when you ask';

  @override
  String get inProgress => 'In progress';

  @override
  String get noOrdersInProgress => 'No delivery in progress. Your parcels show up here as soon as they are sent.';

  @override
  String statusScheduled(String when) {
    return 'Scheduled $when';
  }

  @override
  String get statusSearching => 'Looking for a rider';

  @override
  String get statusRiderComing => 'Rider on the way to pickup';

  @override
  String get statusInDelivery => 'Out for delivery';

  @override
  String get statusFailed => 'Delivery failed · your decision needed';

  @override
  String todayAt(String time) {
    return 'today at $time';
  }

  @override
  String tomorrowAt(String time) {
    return 'tomorrow at $time';
  }

  @override
  String get ordersError => 'Could not load your deliveries.';

  @override
  String get finished => 'Finished';

  @override
  String get noOrdersFinished => 'No finished delivery yet.';

  @override
  String statusDelivered(String day) {
    return 'Delivered · $day';
  }

  @override
  String get statusReturned => 'Returned to sender';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get today => 'today';

  @override
  String get yesterday => 'yesterday';

  @override
  String get referralTitle => 'Referral';

  @override
  String get referralBody => 'Share your code: your friends enter it when signing up and get a discount.';

  @override
  String appVersion(String version) {
    return 'Tara · version $version';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get displaySection => 'Display';

  @override
  String get effectsAutoReduced => 'Reduced automatically on this phone.';

  @override
  String get effectsFull => 'Full';

  @override
  String get effectsHint => 'Reduced: fewer effects, smoother on a modest phone.';

  @override
  String get effectsLabel => 'Animations';

  @override
  String get effectsReduced => 'Reduced';

  @override
  String get helpSection => 'Help';

  @override
  String get languageLabel => 'Language';

  @override
  String get logoutConfirm => 'You will no longer receive notifications on this phone until you sign in again.';

  @override
  String get optionAuto => 'Auto';

  @override
  String get supportTara => 'Tara support';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get prohibitedTitle => 'Prohibited items';

  @override
  String get prohibitedWeapons => 'Weapons, including knives, and ammunition';

  @override
  String get prohibitedIllegal => 'Illegal goods: drugs, counterfeits';

  @override
  String get prohibitedDangerous => 'Dangerous goods: gas, fuel, flammable, explosive or corrosive products';

  @override
  String get prohibitedAnimals => 'Live animals';

  @override
  String get prohibitedCash => 'Bundles of cash';

  @override
  String get prohibitedPledge => 'By sending the parcel, you confirm it contains none of these.';

  @override
  String get close => 'Close';

  @override
  String stepOf(int current, int total, String title) {
    return 'Step $current of $total · $title';
  }

  @override
  String get stepPickup => 'Pickup';

  @override
  String get stepRecipient => 'Recipient';

  @override
  String get stepPackage => 'Parcel';

  @override
  String get stepWhen => 'When';

  @override
  String get stepSummary => 'Summary';

  @override
  String get pickupTitle => 'Where should we collect the parcel?';

  @override
  String get pickupBody => 'The rider picks it up at this address.';

  @override
  String get noPickupYet => 'No saved address yet. Place your shop or home on the map: it will be here next time.';

  @override
  String get addressesError => 'Couldn’t load your addresses.';

  @override
  String get newAddress => 'New address';

  @override
  String get pickupRequired => 'Choose or add the pickup address.';

  @override
  String get pickupAddressTitle => 'Pickup address';

  @override
  String get locationUnavailable => 'Location not found: move the map to the right spot.';

  @override
  String get myPosition => 'My location';

  @override
  String get pinHint => 'Move the map to put the pin on the exact entrance.';

  @override
  String get neighborhoodLabel => 'Neighbourhood';

  @override
  String get neighborhoodAuto => 'Taken from the point on the map';

  @override
  String get neighborhoodSearch => 'Search a neighbourhood';

  @override
  String get landmarkLabel => 'Landmark';

  @override
  String get landmarkHint => 'E.g. Blue gate after the crossroads pharmacy';

  @override
  String get landmarkRequired => 'Describe a visible landmark (at least 3 characters).';

  @override
  String get addressLabel => 'Label';

  @override
  String get labelShop => 'Shop';

  @override
  String get labelHome => 'Home';

  @override
  String get labelOffice => 'Office';

  @override
  String get saveAddress => 'Save address';

  @override
  String get recipientTitle => 'Who receives the parcel?';

  @override
  String get recipientBody => 'We send them delivery tracking by SMS.';

  @override
  String get recipientName => 'Recipient’s name';

  @override
  String get recipientNameHint => 'E.g. Marie Ngo';

  @override
  String get recipientPhone => 'Their number';

  @override
  String get recipientNameRequired => 'Enter the recipient’s name.';

  @override
  String get recentRecipients => 'Recent';

  @override
  String deliveriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count deliveries', one: '1 delivery');
    return '$_temp0';
  }

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String get placeOnMap => 'Place on the map';

  @override
  String get placeOnMapBody => 'You know where to deliver: place the pin yourself.';

  @override
  String get askRecipient => 'Ask the recipient';

  @override
  String get askRecipientBody => 'They get a link and place their own point on the map.';

  @override
  String get viaWhatsapp => 'WhatsApp';

  @override
  String get viaSms => 'SMS';

  @override
  String get recipientFirst => 'First enter the recipient’s name and number.';

  @override
  String linkSentTitle(String name) {
    return 'Link sent to $name';
  }

  @override
  String get linkWaiting =>
      'Waiting for their point: the address shows here as soon as they place it. You can carry on meanwhile.';

  @override
  String get linkExpired => 'The link expired without an answer.';

  @override
  String get resendLink => 'Send the link again';

  @override
  String get placeMyself => 'Place it myself';

  @override
  String get changeAddress => 'Change address';

  @override
  String get addressVerified => 'Address confirmed by a delivery';

  @override
  String get addressFromRecipient => 'Placed by the recipient';

  @override
  String get addressRequired => 'Say where to deliver the parcel.';

  @override
  String get whatsappUnavailable => 'WhatsApp didn’t open. Try SMS.';

  @override
  String get smsUnavailable => 'SMS didn’t open on this phone.';

  @override
  String locationLinkMessage(String name, String sender, String url) {
    return 'Hello $name, $sender is sending you a parcel with Tara. Tell us where to deliver it: $url';
  }

  @override
  String get packageTitle => 'What’s in the parcel?';

  @override
  String get packageBody => 'So the rider knows how to carry it.';

  @override
  String get contentsLabel => 'Contents';

  @override
  String get contentsDocuments => 'Documents';

  @override
  String get contentsClothing => 'Clothes, shoes';

  @override
  String get contentsMedicine => 'Medicines';

  @override
  String get contentsLaundry => 'Laundry';

  @override
  String get contentsHousehold => 'Kitchen, home';

  @override
  String get contentsElectronics => 'Electronics';

  @override
  String get contentsFood => 'Food';

  @override
  String get contentsBeauty => 'Beauty';

  @override
  String get contentsSecondhand => 'Second-hand';

  @override
  String get contentsOther => 'Other';

  @override
  String get contentsRequired => 'Choose what the parcel contains.';

  @override
  String get descriptionLabel => 'Details (optional)';

  @override
  String get descriptionLabelRequired => 'Describe the contents';

  @override
  String get descriptionRequired => 'Say what the parcel contains.';

  @override
  String get descriptionHintDocuments => 'E.g. Signed contract, file';

  @override
  String get descriptionHintClothing => 'E.g. 2 pairs of shoes';

  @override
  String get descriptionHintMedicine => 'E.g. Pharmacy prescription';

  @override
  String get descriptionHintLaundry => 'E.g. 1 bag of ironed laundry';

  @override
  String get descriptionHintHousehold => 'E.g. Pot and 6 glasses';

  @override
  String get descriptionHintElectronics => 'E.g. Phone and charger';

  @override
  String get descriptionHintFood => 'E.g. Birthday cake';

  @override
  String get descriptionHintBeauty => 'E.g. Wig, creams';

  @override
  String get descriptionHintSecondhand => 'E.g. Vintage lamp';

  @override
  String get descriptionHintOther => 'E.g. Motorbike part';

  @override
  String get sizeLabel => 'Size';

  @override
  String sizeMax(int kg) {
    return '≤ $kg kg';
  }

  @override
  String get sizeHelpS => 'Up to 2 kg · fits in one hand: envelope, phone, medicines.';

  @override
  String get sizeHelpM => 'Up to 5 kg · shoe box, small bag of clothes.';

  @override
  String get sizeHelpL => 'Up to 10 kg · medium box, laundry bag.';

  @override
  String get sizeHelpXL => 'Up to 20 kg · large box, small appliance. XL parcel surcharge.';

  @override
  String get fragileTitle => 'Fragile';

  @override
  String get fragileBody => 'The rider carries it with care.';

  @override
  String get codLabel => 'To collect from the recipient';

  @override
  String get codHint => '0 if nothing to collect';

  @override
  String get codHelp =>
      'The rider collects this amount on delivery; it joins your sales, paid out to your Mobile Money.';

  @override
  String get codTooHigh => '500,000 F at most per delivery.';

  @override
  String get valueLabel => 'Value of the contents (optional)';

  @override
  String get valueHint => 'E.g. 25,000';

  @override
  String get valueHelp => 'In FCFA. Shown to the rider, useful in case of dispute.';

  @override
  String get valueTooHigh => '10,000,000 F at most.';

  @override
  String get instructionsLabel => 'Instructions for the rider (optional)';

  @override
  String get instructionsHint => 'E.g. Call on arrival, ring at the green gate';

  @override
  String get soundsLabel => 'Sounds';

  @override
  String get soundsHint => 'Order sent, address received, parcel delivered… Your phone’s silent mode is respected.';

  @override
  String get whenTitle => 'When should the rider come?';

  @override
  String get whenBody => 'They collect the parcel, then deliver it right away.';

  @override
  String get whenNow => 'Now';

  @override
  String get whenNowBody => 'A rider sets off as soon as possible.';

  @override
  String get whenLater => 'Schedule';

  @override
  String get whenLaterBody => 'A day and time, up to 7 days ahead.';

  @override
  String get dayLabel => 'Day';

  @override
  String get timeLabel => 'Pickup time';

  @override
  String get dayToday => 'Today';

  @override
  String get dayTomorrow => 'Tomorrow';

  @override
  String dateAt(String date, String time) {
    return '$date at $time';
  }

  @override
  String scheduledSummary(String when) {
    return 'Pickup planned $when.';
  }

  @override
  String get nightSurcharge => 'Between 8 pm and 6 am, a night surcharge applies.';

  @override
  String get slotRequired => 'Choose a pickup time.';

  @override
  String get salesToday => 'Collected today';

  @override
  String salesDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deliveries',
      one: '1 delivery',
      zero: 'No delivery',
    );
    return '$_temp0';
  }

  @override
  String toReceiveDaily(String amount) {
    return '$amount to receive tonight';
  }

  @override
  String toReceiveOnDemand(String amount) {
    return '$amount to receive';
  }

  @override
  String payoutSent(String amount) {
    return '$amount sent to your Mobile Money';
  }

  @override
  String get summaryTitle => 'Check and order';

  @override
  String get summaryBody => 'The price is worked out for this route and time.';

  @override
  String get whenNowShort => 'As soon as possible';

  @override
  String deliveryNumber(int n) {
    return 'Delivery $n';
  }

  @override
  String waitingPoint(String name) {
    return 'Waiting for $name to place their point';
  }

  @override
  String get removeDelivery => 'Remove';

  @override
  String get addDelivery => 'Add a delivery';

  @override
  String get addDeliveryHint => 'Up to 10 deliveries from the same pickup: one rider visit.';

  @override
  String get priceBase => 'Delivery';

  @override
  String get surchargeExpress => 'Express';

  @override
  String get surchargeHeavy => 'XL parcel';

  @override
  String get surchargeNight => 'Night surcharge';

  @override
  String get surchargeWeather => 'Weather surcharge';

  @override
  String get surchargeOther => 'Surcharge';

  @override
  String get discount => 'Discount';

  @override
  String get totalLabel => 'Total';

  @override
  String get quoting => 'Working out the price…';

  @override
  String get promoLabel => 'Promo code';

  @override
  String get promoHint => 'E.g. WELCOME';

  @override
  String get applyPromo => 'Apply';

  @override
  String promoApplied(String code) {
    return 'Code $code applied';
  }

  @override
  String get whoPays => 'Who pays for the delivery?';

  @override
  String get payerMe => 'Me';

  @override
  String get payerRecipient => 'The recipient';

  @override
  String get recipientPaysBody => 'The recipient pays on delivery, in cash or by Mobile Money.';

  @override
  String get paymentLabel => 'Payment method';

  @override
  String get payMtn => 'MTN Mobile Money';

  @override
  String get payOrange => 'Orange Money';

  @override
  String get payMomoBody => 'You confirm the payment on your phone.';

  @override
  String get payWallet => 'Tara balance';

  @override
  String get payWalletShop => 'My sales';

  @override
  String payWalletBody(String amount) {
    return 'Available: $amount';
  }

  @override
  String walletTooLow(String amount) {
    return 'Available: $amount, not enough for this order.';
  }

  @override
  String get payCash => 'Cash at pickup';

  @override
  String get payCashBody => 'You pay the rider when they collect the parcel.';

  @override
  String get payerPhoneLabel => 'Paying number';

  @override
  String orderFor(String amount) {
    return 'Order · $amount';
  }

  @override
  String get orderSlide => 'Slide to order';

  @override
  String get paymentRequired => 'Choose how to pay.';

  @override
  String linkPendingBlock(String name) {
    return 'Wait for $name to place their point, or place it yourself.';
  }

  @override
  String get payingTitle => 'Confirm the payment on your phone';

  @override
  String payingBody(String amount, String phone) {
    return 'A $amount request is arriving on $phone: enter your Mobile Money PIN to confirm it.';
  }

  @override
  String get paymentFailed => 'The payment didn’t go through.';

  @override
  String get retryPayment => 'Send the request again';

  @override
  String get cancelOrder => 'Cancel the order';

  @override
  String get cancelReasonUnpaid => 'Mobile Money payment not completed';

  @override
  String get placedTitle => 'Order sent!';

  @override
  String get placedScheduledTitle => 'Delivery scheduled!';

  @override
  String get pickupCodeLabel => 'Pickup code';

  @override
  String get pickupCodeHelp =>
      'Give it to the rider when they collect the parcel. Note it down: it won’t be shown again.';

  @override
  String get searchingRider => 'Looking for a rider…';

  @override
  String get riderFound => 'Rider found! They’re coming for the parcel.';

  @override
  String scheduledPickup(String when) {
    return 'The rider will come $when.';
  }

  @override
  String get backHome => 'Back to home';

  @override
  String payWalletShopBody(String amount) {
    return 'Taken from your sales: $amount left to receive.';
  }

  @override
  String get trackAwaitingPayment => 'Waiting for payment';

  @override
  String get trackAwaitingPaymentBody => 'Confirm the Mobile Money payment to start looking for a rider.';

  @override
  String get trackScheduled => 'Scheduled delivery';

  @override
  String get trackSearching => 'Looking for a rider…';

  @override
  String get trackSearchingBody => 'Riders near the pickup are receiving the job.';

  @override
  String trackAssigned(String rider) {
    return '$rider is coming for the parcel';
  }

  @override
  String get trackAssignedBody => 'Give them the pickup code when they arrive.';

  @override
  String trackOnTheWay(String recipient) {
    return 'On the way to $recipient';
  }

  @override
  String trackOnTheWayBody(String time) {
    return 'Parcel collected at $time.';
  }

  @override
  String get trackFailed => 'Delivery failed';

  @override
  String get trackFailedBody => 'The rider couldn’t deliver. Choose what’s next: try again or return.';

  @override
  String get trackDelivered => 'Parcel delivered!';

  @override
  String trackDeliveredBody(String recipient, String time) {
    return 'Handed to $recipient at $time.';
  }

  @override
  String get trackReturned => 'Parcel returned';

  @override
  String get trackCancelled => 'Delivery cancelled';

  @override
  String trackEta(int minutes) {
    return 'About $minutes min';
  }

  @override
  String get stepOrdered => 'Order';

  @override
  String get stepRiderFound => 'Rider';

  @override
  String get stepPickedUp => 'Collected';

  @override
  String get stepDelivered => 'Delivered';

  @override
  String get vehicleMotorbike => 'Motorbike';

  @override
  String get vehicleTricycle => 'Tricycle';

  @override
  String get vehicleCar => 'Car';

  @override
  String callRider(String name) {
    return 'Call $name';
  }

  @override
  String forRecipient(String name) {
    return 'For $name';
  }

  @override
  String get newPickupCode => 'New pickup code';

  @override
  String pickupCodeShown(String code) {
    return 'Pickup code: $code';
  }

  @override
  String get cancelDelivery => 'Cancel the delivery';

  @override
  String get cancelConfirm => 'Tap again to confirm the cancellation.';

  @override
  String get cancelReasonSender => 'Cancelled by the sender';

  @override
  String deliveredBy(String rider) {
    return 'Delivered by $rider';
  }

  @override
  String deliveredIn(int minutes) {
    return 'in $minutes min';
  }

  @override
  String collectedAmount(String amount) {
    return '$amount collected';
  }

  @override
  String get shareRecap => 'Share';

  @override
  String recapShareText(String reference, String recipient, String time) {
    return 'Parcel delivered by Tara · $reference · $recipient · $time';
  }

  @override
  String get trackOrderError => 'Couldn’t load the tracking.';

  @override
  String get trackDelivery => 'Track the delivery';

  @override
  String get statusRetrying => 'Trying again';

  @override
  String get statusReturning => 'Coming back to you';

  @override
  String get failureReasonRecipientAbsent => 'Recipient not there';

  @override
  String get failureReasonRecipientUnreachable => 'Recipient unreachable';

  @override
  String get failureReasonRefused => 'Parcel refused by the recipient';

  @override
  String get failureReasonAddressNotFound => 'Address not found';

  @override
  String get failureReasonPaymentRefused => 'The recipient refused to pay';

  @override
  String get failureReasonOther => 'Other reason';

  @override
  String failureReported(String reason, String rider, String time) {
    return '$reason · reported by $rider at $time';
  }

  @override
  String failureDue(String time) {
    return 'Before $time';
  }

  @override
  String get failureDueBody => 'No answer by then: the parcel is brought back to you.';

  @override
  String get failureRetryTitle => 'Try again';

  @override
  String failureRetryBody(String rider, String recipient) {
    return '$rider goes back to $recipient. Call first to agree on a time.';
  }

  @override
  String get failureReturnTitle => 'Return the parcel';

  @override
  String failureReturnBody(String rider, String place) {
    return '$rider brings the parcel back to you: $place.';
  }

  @override
  String get failureChoose => 'Choose an option';

  @override
  String get failureConfirmRetry => 'Confirm retry';

  @override
  String get failureConfirmReturn => 'Confirm return';

  @override
  String get failureConfirmRetrySemantics => 'Swipe to ask for another attempt';

  @override
  String get failureConfirmReturnSemantics => 'Swipe to have the parcel returned';

  @override
  String callRecipient(String name) {
    return 'Call $name';
  }

  @override
  String get trackRetrying => 'Trying again';

  @override
  String trackRetryingBody(String rider, String recipient) {
    return '$rider is heading back to $recipient.';
  }

  @override
  String get trackReturning => 'Parcel coming back';

  @override
  String trackReturningBody(String rider) {
    return '$rider is bringing the parcel back to you.';
  }

  @override
  String get returnCodeHint =>
      'When the rider hands the parcel back, give them the return code you got by SMS: it proves you received it.';

  @override
  String get newReturnCode => 'New return code';

  @override
  String returnCodeShown(String code) {
    return 'Return code: $code';
  }

  @override
  String trackReturnedBody(String time) {
    return 'The parcel was handed back to you at $time.';
  }

  @override
  String get stepFailed => 'Failed';

  @override
  String get stepReturned => 'Returned';

  @override
  String riderNoteQuoted(String note) {
    return '“$note”';
  }

  @override
  String get returnToPickup => 'Back to the pickup point';

  @override
  String failureBannerTitle(String reference) {
    return 'Delivery failed · $reference';
  }

  @override
  String get failureBannerBody => 'Tap to choose: try again or return.';

  @override
  String get rateTitle => 'How did the delivery go?';

  @override
  String rateBody(String rider) {
    return 'Rate $rider: the best-rated riders get more deliveries.';
  }

  @override
  String starsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count stars', one: '1 star');
    return '$_temp0';
  }

  @override
  String get starWord1 => 'Very poor';

  @override
  String get starWord2 => 'Poor';

  @override
  String get starWord3 => 'Okay';

  @override
  String get starWord4 => 'Good';

  @override
  String get starWord5 => 'Perfect!';

  @override
  String get rateCommentHint => 'A word for the Tara team (optional)';

  @override
  String get rateSend => 'Send my rating';

  @override
  String get rateThanks => 'Thanks for your rating!';

  @override
  String get rateThanksBody => 'Your feedback stays between you and Tara.';

  @override
  String failureFeesNote(String retry, String ret) {
    return 'If delivery fails: another attempt $retry, return of the parcel $ret, charged to you. A returned parcel is handed back against payment of what your Tara balance doesn’t cover.';
  }

  @override
  String get retryUsed => 'Only one more attempt is possible: the parcel will be brought back to you.';

  @override
  String returnFeeHint(String amount) {
    return 'Return fee: $amount, taken from your Tara balance. If it isn’t enough, you pay the rest to the rider when the parcel is handed back (cash or Mobile Money).';
  }

  @override
  String topUpTitle(String amount) {
    return 'Top up $amount for another attempt';
  }

  @override
  String get topUpBody =>
      'Your Tara balance doesn’t cover the fee. Pay by Mobile Money: the new attempt is confirmed as soon as the payment goes through.';

  @override
  String topUpPay(String amount) {
    return 'Pay $amount';
  }

  @override
  String topUpPending(String amount) {
    return 'Approve the $amount payment on your phone with your Mobile Money PIN.';
  }

  @override
  String get topUpFailed => 'The payment didn’t go through. Try again, or choose the return.';

  @override
  String get topUpCancel => 'Choose the return instead';

  @override
  String get termsTitle => 'Terms of use';

  @override
  String get termsUpdateTitle => 'Our terms have changed';

  @override
  String get termsSignupIntro =>
      'Before creating your account, read the terms and the privacy policy to the end. They explain prices, the fees when a delivery fails and what we do with your data.';

  @override
  String get termsUpdateIntro =>
      'Read the new version to the end, then sign it with the code sent by SMS. Until you sign, you can follow your current deliveries but cannot order new ones.';

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
    return 'terms of use (version $version)';
  }

  @override
  String get termsCheckAnd => ' and the ';

  @override
  String get termsCheckPrivacy => 'privacy policy';

  @override
  String get termsCreateAccount => 'Accept and create my account';

  @override
  String get termsGetCode => 'Get the code to sign';

  @override
  String termsCodeSent(String phone) {
    return 'Code sent to $phone. It serves as your signature.';
  }

  @override
  String get termsSign => 'Sign';

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
  String get termsToSign => 'New version to read and sign';

  @override
  String get termsSigned => 'Terms signed. Thank you!';

  @override
  String get termsPrivacyTitle => 'Privacy policy';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get shopToReceive => 'Sales to receive';

  @override
  String shopPayoutDaily(String hour, String phone) {
    return 'Paid out every day at $hour:00 to $phone.';
  }

  @override
  String shopPayoutOnDemand(String phone) {
    return 'Paid out on request to $phone.';
  }

  @override
  String shopToday(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deliveries',
      one: '1 delivery',
      zero: 'no deliveries',
    );
    return 'Today: $amount collected · $_temp0';
  }

  @override
  String shopDebt(String amount) {
    return 'Failure fees due: $amount. They will be taken from your next sales; above 3,000 F, new orders wait until they are paid.';
  }

  @override
  String payoutOpen(String amount) {
    return 'Payout in progress: $amount';
  }

  @override
  String payoutNow(String amount) {
    return 'Receive $amount now';
  }

  @override
  String get payoutRequested => 'Payout requested: the money is on its way to your Mobile Money.';

  @override
  String get taraBalance => 'Tara balance';

  @override
  String get taraBalanceBody => 'Pays for your deliveries and any failure fees.';

  @override
  String get topUpAction => 'Top up';

  @override
  String get withdrawAction => 'Withdraw';

  @override
  String get topUpHowMuch => 'How much do you want to add?';

  @override
  String topUpDone(String amount) {
    return 'Balance topped up by $amount.';
  }

  @override
  String withdrawBody(String amount, String phone) {
    return 'Your whole balance ($amount) goes to your number $phone.';
  }

  @override
  String withdrawConfirm(String amount) {
    return 'Withdraw $amount';
  }

  @override
  String get withdrawDone => 'Withdrawal requested: the money is on its way to your Mobile Money.';

  @override
  String get movements => 'Activity';

  @override
  String get movementsShop => 'Shop';

  @override
  String get movementsBalance => 'Tara balance';

  @override
  String get movementsEmpty => 'No activity yet.';

  @override
  String get seeMore => 'See more';

  @override
  String get lineCodCollected => 'Sale collected';

  @override
  String get lineOrderCharged => 'Delivery paid';

  @override
  String get lineOrderReleased => 'Fees returned (cancelled)';

  @override
  String get lineFailureFee => 'Failure fee';

  @override
  String get lineCredit => 'Credit from Tara';

  @override
  String get lineTopUp => 'Top-up';

  @override
  String get linePayout => 'Payout';

  @override
  String get lineWithdrawal => 'Withdrawal';

  @override
  String get linePayoutFailed => 'Payout failed, amount returned';

  @override
  String get lineRefund => 'Refund';

  @override
  String get payoutsTitle => 'Payouts';

  @override
  String get payoutStatusDone => 'Received';

  @override
  String get payoutStatusOpen => 'In progress';

  @override
  String get payoutStatusFailed => 'Failed, amount returned';

  @override
  String get statementsTitle => 'Monthly statements';

  @override
  String get statementsBody => 'Each month’s PDF statement: sales, fees, payouts, balances.';

  @override
  String statementCurrent(String month) {
    return '$month (in progress)';
  }

  @override
  String statementShare(String month) {
    return 'Tara statement for $month';
  }

  @override
  String walletBalanceTile(String amount) {
    return 'Tara balance: $amount';
  }

  @override
  String get askTitle => 'Ask for the address';

  @override
  String get askIntro =>
      'Send your customer a link: they place their own point and write a landmark. You are told as soon as it is done, and the delivery is created with their address.';

  @override
  String get askSendWhatsapp => 'Send by WhatsApp';

  @override
  String get askSendSms => 'By SMS';

  @override
  String askSent(String name) {
    return 'Link sent to $name. You will be told as soon as they place their point.';
  }

  @override
  String get askRequested => 'Requested addresses';

  @override
  String get askNone => 'No address requested yet.';

  @override
  String askPending(String date) {
    return 'Waiting · link valid until $date';
  }

  @override
  String askReceived(String landmark) {
    return 'Point received · $landmark';
  }

  @override
  String get askExpired => 'Expired without reply';

  @override
  String get askCreateOrder => 'Create the delivery';

  @override
  String get askResend => 'Send again';

  @override
  String askArrived(String name) {
    return '$name placed their point: you can create the delivery.';
  }

  @override
  String get myAddresses => 'My addresses';

  @override
  String get myAddressesEmpty => 'Save your shop or your home: they will be offered for pickups.';

  @override
  String get addAddress => 'Add an address';

  @override
  String get newAddressTitle => 'New address';

  @override
  String removeAddress(String label) {
    return 'Remove $label';
  }

  @override
  String removeAddressConfirm(String label) {
    return 'Remove “$label” from your addresses? Past deliveries are not affected.';
  }

  @override
  String get removeYes => 'Yes, remove';
}

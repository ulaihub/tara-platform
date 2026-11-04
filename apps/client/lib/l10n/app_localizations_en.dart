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
  String get legalPrefix => 'By continuing, you accept the ';

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
}

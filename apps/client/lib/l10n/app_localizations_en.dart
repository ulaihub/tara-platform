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
  String hello(String name) {
    return 'Hello $name';
  }

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
}

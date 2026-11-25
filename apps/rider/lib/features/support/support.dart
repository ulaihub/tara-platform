import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tara_core/api/support_api.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/support_flow.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';

/// Motifs proposés à un livreur : gains et solde, colis perdu ou abîmé, app, autre.
const riderCategories = [
  SupportCategory.payment,
  SupportCategory.lostParcel,
  SupportCategory.damagedParcel,
  SupportCategory.appBug,
  SupportCategory.other,
];

/// Libellés du service client dans la langue de l'app.
SupportStrings supportStrings(BuildContext context) {
  final l = AppLocalizations.of(context);
  final when = DateFormat('d MMM, HH:mm', l.localeName);
  return SupportStrings(
    back: l.back,
    retry: l.retry,
    title: l.supportTitle,
    intro: l.supportIntro,
    newRequest: l.supportNewRequest,
    empty: l.supportEmpty,
    callUs: l.supportCallUs,
    category: (category) => switch (category) {
      SupportCategory.payment => l.supportCategoryPayment,
      SupportCategory.lostParcel => l.supportCategoryLostParcel,
      SupportCategory.damagedParcel => l.supportCategoryDamagedParcel,
      SupportCategory.appBug => l.supportCategoryAppBug,
      // Pas proposés à un livreur ; une demande ouverte par l'équipe peut les porter.
      SupportCategory.lateDelivery || SupportCategory.riderBehavior || SupportCategory.other => l.supportCategoryOther,
    },
    status: (status) => switch (status) {
      SupportStatus.open => l.supportStatusOpen,
      SupportStatus.inProgress => l.supportStatusInProgress,
      SupportStatus.resolved => l.supportStatusResolved,
      SupportStatus.closed => l.supportStatusClosed,
    },
    newTitle: l.supportNewTitle,
    reasonLabel: l.supportReasonLabel,
    subjectLabel: l.supportSubjectLabel,
    subjectHint: l.supportSubjectHint,
    messageLabel: l.supportMessageLabel,
    messageHint: l.supportMessageHint,
    orderLine: l.supportOrderLine,
    send: l.supportSend,
    replyHint: l.supportReplyHint,
    replySend: l.supportReplySend,
    closedNote: l.supportClosedNote,
    fromTara: l.supportFromTara,
    newAnswer: l.supportNewAnswer,
    waitingNote: l.supportWaitingNote,
    when: when.format,
    errorText: (error) => errorMessage(context, error),
  );
}

/// Aide et service client : demandes du livreur, nouvelle demande, appel.
Future<void> openSupport(BuildContext context, WidgetRef ref) {
  final phone = ref.read(riderConfigProvider).value?.supportPhone;
  return Navigator.of(context).push(
    scopedPage<void>(
      context,
      (route) => SupportHomeScreen(
        backend: ref.read(supportBackendProvider),
        strings: supportStrings(route),
        categories: riderCategories,
        onBack: () => Navigator.of(route).pop(),
        updates: ref.read(realtimeProvider).supportReplies,
        supportPhone: phone == null ? null : displayPhone(phone),
        onCall: phone == null ? null : () => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: phone))),
      ),
    ),
  );
}

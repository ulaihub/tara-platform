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

/// Motifs proposés à un expéditeur (une boutique, un particulier).
const senderCategories = [
  SupportCategory.lostParcel,
  SupportCategory.damagedParcel,
  SupportCategory.lateDelivery,
  SupportCategory.payment,
  SupportCategory.riderBehavior,
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
      SupportCategory.lostParcel => l.supportCategoryLostParcel,
      SupportCategory.damagedParcel => l.supportCategoryDamagedParcel,
      SupportCategory.lateDelivery => l.supportCategoryLateDelivery,
      SupportCategory.payment => l.supportCategoryPayment,
      SupportCategory.riderBehavior => l.supportCategoryRiderBehavior,
      SupportCategory.appBug => l.supportCategoryAppBug,
      SupportCategory.other => l.supportCategoryOther,
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

/// Aide et service client : demandes de l'expéditeur, nouvelle demande, appel.
Future<void> openSupport(BuildContext context, WidgetRef ref) {
  final phone = ref.read(appConfigProvider).value?.supportPhone;
  return Navigator.of(context).push(
    scopedPage<void>(
      context,
      (route) => SupportHomeScreen(
        backend: ref.read(supportBackendProvider),
        strings: supportStrings(route),
        categories: senderCategories,
        onBack: () => Navigator.of(route).pop(),
        updates: ref.read(realtimeProvider).supportReplies,
        supportPhone: phone == null ? null : displayPhone(phone),
        onCall: phone == null ? null : () => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: phone))),
      ),
    ),
  );
}

/// « Signaler un problème » depuis le suivi d'une livraison : la demande porte sur cette
/// commande ; une fois envoyée, ses échanges s'ouvrent.
Future<void> reportProblem(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
  required String orderReference,
}) async {
  final navigator = Navigator.of(context);
  final backend = ref.read(supportBackendProvider);
  await navigator.push(
    scopedPage<void>(
      context,
      (route) => SupportNewScreen(
        backend: backend,
        strings: supportStrings(route),
        categories: senderCategories,
        orderId: orderId,
        orderReference: orderReference,
        onBack: () => Navigator.of(route).pop(),
        // Les échanges remplacent le formulaire (ouverts depuis l'écran du suivi, qui porte
        // les fournisseurs de l'app).
        onCreated: (ticket) => unawaited(
          navigator.pushReplacement(
            scopedPage<void>(
              context,
              (thread) => SupportThreadScreen(
                backend: backend,
                strings: supportStrings(thread),
                ticket: ticket,
                updates: ref.read(realtimeProvider).supportReplies,
                onBack: () => Navigator.of(thread).pop(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

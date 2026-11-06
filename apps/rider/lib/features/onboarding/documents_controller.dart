import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';

enum DocumentStatus { toDo, uploading, sent, approved, rejected, expired }

/// État d'une pièce exigée, d'après le dossier renvoyé par l'API.
@immutable
class DocumentItem {
  const DocumentItem({
    required this.requirement,
    required this.status,
    this.progress = 0,
    this.rejectionReason,
    this.error,
  });

  final DocumentRequirement requirement;
  final DocumentStatus status;
  final double progress;
  final String? rejectionReason;
  final String? error;

  DocumentOption get main => requirement.options.first;
  bool get done => status == DocumentStatus.sent || status == DocumentStatus.approved;
}

@immutable
class DocumentsState {
  const DocumentsState({
    required this.requirements,
    required this.profile,
    this.uploads = const {},
    this.errors = const {},
  });

  final List<DocumentRequirement> requirements;
  final RiderProfile profile;

  /// Envois en cours : type → progression (0 à 1).
  final Map<String, double> uploads;
  final Map<String, String> errors;

  List<DocumentItem> get items => [for (final requirement in requirements) _item(requirement)];
  int get doneCount => items.where((item) => item.done).length;
  bool get complete => doneCount == requirements.length;

  DocumentItem _item(DocumentRequirement requirement) {
    final types = requirement.options.map((o) => o.type).toSet();
    final uploading = uploads.entries.where((e) => types.contains(e.key)).firstOrNull;
    final error = errors.entries.where((e) => types.contains(e.key)).firstOrNull?.value;
    if (uploading != null) {
      return DocumentItem(requirement: requirement, status: DocumentStatus.uploading, progress: uploading.value);
    }
    // La pièce la meilleure du groupe : validée, puis envoyée, puis refusée ou expirée.
    final docs = profile.documents.where((d) => types.contains(d.type)).toList();
    KycDocument? find(String status) => docs.where((d) => d.status == status).firstOrNull;
    final approved = find('APPROVED');
    if (approved != null) {
      return DocumentItem(requirement: requirement, status: DocumentStatus.approved, error: error);
    }
    if (find('PENDING') != null) {
      return DocumentItem(requirement: requirement, status: DocumentStatus.sent, error: error);
    }
    final rejected = find('REJECTED');
    if (rejected != null) {
      return DocumentItem(
        requirement: requirement,
        status: DocumentStatus.rejected,
        rejectionReason: rejected.rejectionReason,
        error: error,
      );
    }
    if (find('EXPIRED') != null) {
      return DocumentItem(requirement: requirement, status: DocumentStatus.expired, error: error);
    }
    return DocumentItem(requirement: requirement, status: DocumentStatus.toDo, error: error);
  }

  DocumentsState copyWith({RiderProfile? profile, Map<String, double>? uploads, Map<String, String>? errors}) =>
      DocumentsState(
        requirements: requirements,
        profile: profile ?? this.profile,
        uploads: uploads ?? this.uploads,
        errors: errors ?? this.errors,
      );
}

/// Pièces du livreur : liste exigée par l'API, envoi avec progression, dossier rafraîchi.
class DocumentsController extends AsyncNotifier<DocumentsState> {
  @override
  Future<DocumentsState> build() async {
    final api = ref.read(riderApiProvider);
    final requirements = await api.requirements();
    final profile = await api.profile();
    return DocumentsState(requirements: requirements, profile: profile);
  }

  /// Dossier renvoyé par une autre action (contact d'urgence modifié dans le profil).
  void replaceProfile(RiderProfile profile) {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(profile: profile));
  }

  Future<void> upload(
    String type,
    String filePath, {
    DateTime? expiresOn,
    String Function(Object error)? describe,
  }) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(uploads: {...current.uploads, type: 0}, errors: {...current.errors}..remove(type)),
    );
    final api = ref.read(riderApiProvider);
    try {
      await api.uploadDocument(
        type: type,
        filePath: filePath,
        expiresOn: expiresOn,
        onProgress: (progress) {
          final now = state.value;
          if (now != null) state = AsyncData(now.copyWith(uploads: {...now.uploads, type: progress}));
        },
      );
      final profile = await api.profile();
      final now = state.value!;
      state = AsyncData(now.copyWith(profile: profile, uploads: {...now.uploads}..remove(type)));
    } catch (error) {
      final now = state.value!;
      state = AsyncData(
        now.copyWith(
          uploads: {...now.uploads}..remove(type),
          errors: {...now.errors, type: describe?.call(error) ?? '$error'},
        ),
      );
    }
  }
}

final documentsControllerProvider = AsyncNotifierProvider<DocumentsController, DocumentsState>(DocumentsController.new);

import 'package:tara_ui/components/progress.dart';

import '../../l10n/app_localizations.dart';

/// États des étapes de la course, lus par le lecteur d'écran dans la langue de l'app.
StepStateLabels stepStateLabels(AppLocalizations l) =>
    StepStateLabels(done: l.stepDone, active: l.stepActive, upcoming: l.stepUpcoming);

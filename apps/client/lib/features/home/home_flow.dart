import 'package:flutter/widgets.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/tara_icons.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// Onglets de l'expéditeur (Accueil, Commandes, Profil) : le contenu défile sous la barre en
/// verre, transition vitrée d'un onglet à l'autre. Les écrans suivants (nouvelle livraison,
/// lien de localisation, suivi) se branchent ici au fil de la phase 5.
class HomeFlow extends StatefulWidget {
  const HomeFlow({super.key, required this.me});

  final Me me;

  @override
  State<HomeFlow> createState() => _HomeFlowState();
}

class _HomeFlowState extends State<HomeFlow> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TaraTabShell(
      items: [
        TabItem(TaraIcons.home, l.tabHome),
        TabItem(TaraIcons.package, l.tabOrders),
        TabItem(TaraIcons.user, l.tabProfile),
      ],
      current: _tab,
      onSelected: (tab) => setState(() => _tab = tab),
      child: switch (_tab) {
        1 => OrdersScreen(onOpenOrder: (_) {}),
        2 => ProfileScreen(me: widget.me),
        _ => HomeScreen(me: widget.me, onNewOrder: () {}, onLocationLink: () {}, onOpenOrder: (_) {}, onWallet: () {}),
      },
    );
  }
}

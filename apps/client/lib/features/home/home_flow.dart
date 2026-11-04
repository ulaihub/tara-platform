import 'package:flutter/widgets.dart';

import '../../core/api/client_models.dart';
import 'home_screen.dart';

/// Accueil et onglets de l'expéditeur. Les écrans suivants (nouvelle livraison, lien de
/// localisation, suivi, commandes, profil) se branchent ici au fil de la phase 5.
class HomeFlow extends StatefulWidget {
  const HomeFlow({super.key, required this.me});

  final Me me;

  @override
  State<HomeFlow> createState() => _HomeFlowState();
}

class _HomeFlowState extends State<HomeFlow> {
  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      me: widget.me,
      onNewOrder: () {},
      onLocationLink: () {},
      onOpenOrder: (_) {},
      onWallet: () {},
      onTab: (_) {},
    );
  }
}

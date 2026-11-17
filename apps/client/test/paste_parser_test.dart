import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/features/bulk/paste_parser.dart';

const _quartiers = ['Bonapriso', 'Deïdo', 'Bépanda', 'Akwa', 'Akwa Nord', 'Makepe', 'Bali'];

void main() {
  test('lit la liste des maquettes, comme une boutique la colle depuis WhatsApp', () {
    final lines = parseList('''
Marie 690112233 Bonapriso pharmacie 12500
Jean Mbarga 677445566 Deido immeuble bleu

Chantal 6 99 88 77 66 Bepanda
Samuel Etoa 655443322 Akwa boulangerie 8000
Brice 69912 Makepe
Awa 690 55 44 33 Bali carrefour 15000
''', neighborhoods: _quartiers);
    expect(lines, hasLength(6));
    expect(
      [for (final l in lines) (l.name, l.phone, l.neighborhood, l.amount, l.problem)],
      [
        ('Marie', '690112233', 'Bonapriso', 12500, null),
        ('Jean Mbarga', '677445566', 'Deïdo', 0, null),
        ('Chantal', '699887766', 'Bépanda', 0, null),
        ('Samuel Etoa', '655443322', 'Akwa', 8000, null),
        ('Brice', null, 'Makepe', 0, LineProblem.phoneIncomplete),
        ('Awa', '690554433', 'Bali', 15000, null),
      ],
    );
    expect(lines[0].hint, 'Bonapriso pharmacie');
    expect(lines[4].rawPhone, '69912');
  });

  test('reconnaît les écritures courantes des numéros et des montants', () {
    ParsedLine one(String text) => parseLine(text, neighborhoods: _quartiers);
    expect(
      one('Grace +237 690-55-44-33 akwa nord 15 000 FCFA'),
      isA<ParsedLine>()
          .having((l) => l.phone, 'numéro', '690554433')
          .having((l) => l.amount, 'montant', 15000)
          .having((l) => l.neighborhood, 'quartier le plus précis', 'Akwa Nord'),
    );
    expect(one('00237677000111 Paul Bali').phone, '677000111');
    expect(one('Paul 677000111 Bali 15k').amount, 15000);
    expect(one('Paul 677000111 Bali 12.500F').amount, 12500);
    // Un nombre trop grand n'est pas un montant à encaisser.
    expect(one('Paul 677000111 Bali 9000000').amount, 0);
    // Numéro en premier : le nom vient juste après.
    final first = one('690112233 Marie Bonapriso');
    expect((first.name, first.hint), ('Marie', 'Bonapriso'));
    // Message transféré : l'heure est retirée.
    expect(parseList('[17/11 09:12] Rose 690112233 Akwa').single.name, 'Rose');
  });

  test('signale ce qui manque, sans rien inventer', () {
    final missing = parseLine('Clarisse Bonamoussadi');
    expect(missing.problem, LineProblem.phoneMissing);
    expect(missing.name, 'Clarisse Bonamoussadi');
    expect(parseLine('690112233 12500').problem, LineProblem.nameMissing);
    expect(parseList('a\n' * 150, limit: 100), hasLength(100));
  });
}

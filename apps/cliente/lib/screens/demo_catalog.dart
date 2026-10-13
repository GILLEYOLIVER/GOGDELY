// Fictional catalogue for the local visual prototype. Never use these prices
// or availability for a real order; FastAPI remains the authority (GOG-017/080).
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class DemoProduct {
  const DemoProduct(this.id, this.name, this.description, this.priceCents,
      {this.image = '',
      this.badge = '',
      this.category = '',
      this.stockQuantity,
      this.addons = const [],
      this.originalPriceCents});
  final String id;
  final String name;
  final String description;
  final int priceCents;
  final String image;
  final String badge;
  final String category;
  final int? stockQuantity;
  final List<DemoAddon> addons;

  /// Original price before the active promotion (GOG-021), null when absent.
  final int? originalPriceCents;
}

class DemoStore {
  const DemoStore(
      this.id, this.name, this.category, this.description, this.products,
      {this.image = '', this.rating = '4,8', this.eta = '25–35 min'});
  final String id;
  final String name;
  final String category;
  final String description;
  final List<DemoProduct> products;
  final String image;
  final String rating;
  final String eta;
}

const demoStores = <DemoStore>[
  DemoStore(
      'burger-house',
      'Burger House',
      'Restaurantes',
      'Hambúrgueres artesanais',
      [
        DemoProduct(
            'x-tudo', 'X-Tudo', 'Pão, carne, queijo, bacon e alface.', 2890,
            image: 'assets/images/burger.png'),
        DemoProduct('batata', 'Batata Especial', 'Crocante e temperada.', 1890,
            image: 'assets/images/burger.png'),
        DemoProduct(
            'refrigerante', 'Refrigerante Lata', 'Lata de 350 ml.', 690),
      ],
      image: 'assets/images/burger.png',
      eta: '15–25 min'),
  DemoStore(
      'pizzaria-napoli',
      'Pizzaria Napoli',
      'Restaurantes',
      'Pizzas artesanais feitas na hora',
      [
        DemoProduct(
            'margherita',
            'Pizza Margherita',
            'Molho de tomate, mussarela, manjericão fresco e azeite de oliva.',
            3290,
            image: 'assets/images/pizza.png'),
        DemoProduct('calabresa', 'Pizza Calabresa', 'Calabresa e cebola.', 3490,
            image: 'assets/images/pizza.png'),
        DemoProduct(
            'portuguesa', 'Pizza Portuguesa', 'Presunto, ovo e queijo.', 3690,
            image: 'assets/images/pizza.png'),
      ],
      image: 'assets/images/pizza.png',
      eta: '25–35 min'),
  DemoStore(
      'sushi-express',
      'Sushi Express',
      'Restaurantes',
      'Sabores japoneses',
      [
        DemoProduct('combo-sushi', 'Combo Sushi',
            'Sushis variados de demonstração.', 4990,
            image: 'assets/images/sushi.png'),
      ],
      image: 'assets/images/sushi.png',
      eta: '30–40 min'),
  DemoStore(
      'mercado-mais',
      'Mercado Mais',
      'Mercado',
      'Tudo para o seu dia a dia',
      [
        DemoProduct('cesta', 'Cesta de frutas', 'Frutas variadas.', 2490),
        DemoProduct('cafe', 'Café moído', 'Pacote fictício de 250 g.', 1890),
      ],
      eta: '20–35 min'),
  DemoStore(
      'farmacia-saude',
      'Farmácia Saúde',
      'Farmácia',
      'Cuidados e conveniência',
      [
        DemoProduct(
            'kit-higiene', 'Kit de higiene', 'Itens de demonstração.', 1590),
      ],
      eta: '20–30 min'),
];

String formatDemoPrice(int cents) {
  final reais = cents ~/ 100;
  final centavos = (cents % 100).toString().padLeft(2, '0');
  return 'R\$ $reais,$centavos';
}

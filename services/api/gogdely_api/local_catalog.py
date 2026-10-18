"""Fictional stores for the isolated SQLite laboratory (GOG-016/017/025).

The names, addresses, prices and coordinates below are test data. This module
is never a production merchant registry or a source of payment authority.
"""

from __future__ import annotations


def _item(product_id: str, name: str, description: str, category: str,
          price_cents: int, image: str, promo_percent: int = 0) -> dict:
    return dict(product_id=product_id, name=name, description=description,
                category=category, price_cents=price_cents, image_ref=image,
                promo_percent=promo_percent)


STORES: dict[str, dict] = {
    "burger-house": dict(name="Burger House", category="Restaurantes",
        description="Hambúrgueres artesanais", eta="15–25 min",
        image="assets/images/burger.png", latitude=-16.6874, longitude=-49.2656,
        products=[
            _item("x-tudo", "X-Tudo", "Pão, carne, queijo, bacon e alface.", "Hambúrgueres", 2890, "assets/images/burger.png"),
            _item("batata", "Batata Especial", "Crocante e temperada.", "Acompanhamentos", 1890, "assets/images/burger.png"),
            _item("refrigerante", "Refrigerante Lata", "Lata de 350 ml.", "Bebidas", 690, ""),
        ]),
    "pizzaria-napoli": dict(name="Pizzaria Napoli", category="Restaurantes",
        description="Pizzas de forno com massa artesanal", eta="25–40 min",
        image="assets/images/pizza.png", latitude=-16.6804, longitude=-49.2721,
        products=[
            _item("margherita", "Pizza Margherita", "Mussarela, tomate e manjericão.", "Pizzas", 3290, "assets/images/pizza.png", 10),
            _item("calabresa", "Pizza Calabresa", "Calabresa, queijo e cebola.", "Pizzas", 3490, "assets/images/pizza.png"),
            _item("portuguesa", "Pizza Portuguesa", "Presunto, ovo, cebola e queijo.", "Pizzas", 3690, "assets/images/pizza.png"),
            _item("broto-queijo", "Pizza Broto de Queijo", "Porção individual com mussarela.", "Pizzas", 2190, "assets/images/pizza.png"),
        ]),
    "sushi-express": dict(name="Sushi Express", category="Restaurantes",
        description="Combinados japoneses para compartilhar", eta="30–45 min",
        image="assets/images/sushi.png", latitude=-16.6922, longitude=-49.2584,
        products=[
            _item("combo-sushi", "Combo Sushi", "Seleção de 20 peças variadas.", "Combinados", 4990, "assets/images/sushi.png"),
            _item("hot-roll", "Hot Roll", "Porção crocante de 8 peças.", "Combinados", 2990, "assets/images/sushi.png"),
            _item("temaki-salmao", "Temaki de Salmão", "Temaki com arroz e salmão.", "Temakis", 2690, "assets/images/sushi.png"),
        ]),
    "acai-central": dict(name="Açaí Central", category="Restaurantes",
        description="Açaí e frutas montados na hora", eta="15–30 min",
        image="assets/images/acai-commons.jpg", latitude=-16.6838, longitude=-49.2608,
        products=[
            _item("acai-300", "Açaí 300 ml", "Açaí com banana e granola.", "Açaí", 1990, "assets/images/acai-commons.jpg", 10),
            _item("acai-500", "Açaí 500 ml", "Açaí com banana, morango e granola.", "Açaí", 2790, "assets/images/acai-commons.jpg"),
            _item("salada-frutas", "Salada de Frutas", "Frutas frescas em porção individual.", "Frutas", 1690, "assets/images/hortifruti-original.png"),
        ]),
    "cantina-brasil": dict(name="Cantina Brasil", category="Restaurantes",
        description="Pratos brasileiros e almoço caseiro", eta="20–35 min",
        image="assets/images/cantina-original.png", latitude=-16.6903, longitude=-49.2699,
        products=[
            _item("prato-frango", "Prato de Frango", "Arroz, feijão, frango, farofa e salada.", "Pratos", 3190, "assets/images/cantina-original.png"),
            _item("feijoada", "Feijoada Individual", "Feijoada, arroz, couve e farofa.", "Pratos", 3690, "assets/images/cantina-original.png"),
            _item("marmita-veg", "Marmita Vegetariana", "Arroz, feijão, legumes e salada.", "Pratos", 2890, "assets/images/cantina-original.png"),
        ]),
    "padaria-aurora": dict(name="Padaria Aurora", category="Padaria",
        description="Pães, café e lanches frescos", eta="15–25 min",
        image="assets/images/padaria-original.png", latitude=-16.6786, longitude=-49.2644,
        products=[
            _item("pao-queijo", "Pão de Queijo", "Porção com 6 unidades.", "Padaria", 1490, "assets/images/padaria-original.png", 10),
            _item("croissant", "Croissant", "Croissant amanteigado.", "Padaria", 1290, "assets/images/padaria-original.png"),
            _item("cafe-leite", "Café com Leite", "Copo de 300 ml.", "Bebidas", 890, "assets/images/padaria-original.png"),
        ]),
    "mercado-mais": dict(name="Mercado Mais", category="Mercado",
        description="Itens do dia a dia e hortifruti", eta="20–35 min",
        image="assets/images/hortifruti-original.png", latitude=-16.6950, longitude=-49.2710,
        products=[
            _item("cesta", "Cesta de Frutas", "Frutas variadas para a semana.", "Hortifruti", 2490, "assets/images/hortifruti-original.png"),
            _item("cafe", "Café Moído", "Pacote fictício de 250 g.", "Mercearia", 1890, "assets/images/padaria-original.png"),
            _item("verduras", "Kit de Verduras", "Alface, tomate e cenoura.", "Hortifruti", 1590, "assets/images/hortifruti-original.png"),
        ]),
    "hortifruti-viva": dict(name="Hortifruti Viva", category="Mercado",
        description="Frutas e verduras frescas", eta="20–35 min",
        image="assets/images/hortifruti-original.png", latitude=-16.6856, longitude=-49.2757,
        products=[
            _item("frutas-estacao", "Frutas da Estação", "Seleção de frutas frescas.", "Frutas", 2290, "assets/images/hortifruti-original.png"),
            _item("legumes-semana", "Legumes da Semana", "Cenoura, tomate e folhas.", "Verduras", 1790, "assets/images/hortifruti-original.png"),
            _item("suco-laranja", "Suco de Laranja", "Garrafa de 500 ml.", "Bebidas", 1190, "assets/images/hortifruti-original.png"),
        ]),
    "farmacia-saude": dict(name="Farmácia Saúde", category="Farmácia",
        description="Higiene e cuidado pessoal sem medicamentos", eta="20–30 min",
        image="assets/images/farmacia-original.png", latitude=-16.6824, longitude=-49.2782,
        products=[
            _item("kit-higiene", "Kit de Higiene", "Sabonete e itens básicos de cuidado.", "Higiene", 1590, "assets/images/farmacia-original.png"),
            _item("protetor-solar", "Protetor Solar", "Produto demonstrativo sem marca.", "Cuidados", 3490, "assets/images/farmacia-original.png"),
            _item("sabonete", "Sabonete", "Barra neutra de demonstração.", "Higiene", 490, "assets/images/farmacia-original.png"),
        ]),
    "pet-amigo": dict(name="Pet Amigo", category="Pet Shop",
        description="Alimentos e acessórios para animais", eta="25–40 min",
        image="assets/images/pet-original.png", latitude=-16.6968, longitude=-49.2617,
        products=[
            _item("racao-caes", "Ração para Cães", "Pacote demonstrativo de 1 kg.", "Alimentação", 2990, "assets/images/pet-original.png"),
            _item("brinquedo-corda", "Brinquedo de Corda", "Brinquedo para cães.", "Acessórios", 1390, "assets/images/pet-original.png"),
            _item("coleira", "Coleira Ajustável", "Coleira demonstrativa para cães.", "Acessórios", 1890, "assets/images/pet-original.png"),
        ]),
}

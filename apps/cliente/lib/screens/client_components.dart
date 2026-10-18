import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

import 'demo_catalog.dart';

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 27, this.center = false});
  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) => RichText(
        textAlign: center ? TextAlign.center : TextAlign.start,
        text: TextSpan(
          style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: Theme.of(context).colorScheme.onSurface),
          children: const [
            TextSpan(text: 'gog'),
            TextSpan(
                text: 'dely.', style: TextStyle(color: GogdelyColors.blue)),
          ],
        ),
      );
}

class DemoPhoto extends StatelessWidget {
  const DemoPhoto(this.path, {super.key, this.height = 150, this.radius = 16});
  final String path;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: path.isEmpty
            ? Container(
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: const Center(child: Icon(Icons.storefront, size: 44)),
              )
            : path.startsWith('https://') ||
                    path.startsWith('/api/v1/local/uploads/')
                ? Image.network(
                    path.startsWith('/') ? '$localDemoBaseUrl$path' : path,
                    height: height,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageError(context))
                : Image.asset(path,
                    height: height,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageError(context)),
      );

  Widget _imageError(BuildContext context) => Container(
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      );
}

const demoCategories = <(String, IconData, Color)>[
  ('Restaurantes', Icons.restaurant, GogdelyColors.blue),
  ('Padaria', Icons.bakery_dining, GogdelyColors.blue),
  ('Mercado', Icons.shopping_basket, GogdelyColors.blue),
  ('Farmácia', Icons.medical_services, GogdelyColors.accent),
  ('Bebidas', Icons.local_drink, GogdelyColors.blue),
  ('Pet Shop', Icons.pets, GogdelyColors.blue),
  ('Lojas', Icons.storefront, GogdelyColors.blueHover),
  ('Doces', Icons.cake, GogdelyColors.accent),
  ('Saúde e Beleza', Icons.spa, GogdelyColors.blue),
  ('Mais', Icons.more_horiz, GogdelyColors.blue),
];

class DemoStoreCard extends StatelessWidget {
  const DemoStoreCard(this.store,
      {super.key,
      required this.onTap,
      this.compact = false,
      this.localPreview = false,
      this.isFavorite = false,
      this.onFavorite});
  final DemoStore store;
  final VoidCallback onTap;
  final bool compact;
  final bool localPreview;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(
                  width: compact ? 64 : 76,
                  height: compact ? 64 : 76,
                  child: ClipOval(
                      child: DemoPhoto(store.image,
                          height: compact ? 64 : 76, radius: 0))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(store.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 7, runSpacing: 4, children: [
                      if (!localPreview) ...[
                        const Icon(Icons.star_rounded,
                            size: 15, color: GogdelyColors.blue),
                        Text(store.rating,
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                      const Icon(Icons.schedule_outlined,
                          size: 14, color: GogdelyColors.blue),
                      Text(localPreview ? '${store.eta} · prévia' : store.eta,
                          style: Theme.of(context).textTheme.labelSmall),
                    ]),
                    const SizedBox(height: 5),
                    Text(store.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                    if (store.products
                        .any((product) => product.badge.isNotEmpty))
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text('Ofertas no cardápio',
                              style: const TextStyle(
                                  color: GogdelyColors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700))),
                  ])),
              if (onFavorite != null)
                IconButton(
                    tooltip: isFavorite
                        ? 'Remover ${store.name} dos favoritos'
                        : 'Favoritar ${store.name}',
                    onPressed: onFavorite,
                    icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? GogdelyColors.blue
                            : Theme.of(context).colorScheme.outline)),
            ]),
          ),
        ),
      );
}

class DemoProductTile extends StatelessWidget {
  const DemoProductTile(this.product, {super.key, required this.onTap});
  final DemoProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(children: [
              SizedBox(
                  width: 78,
                  height: 78,
                  child: DemoPhoto(product.image, height: 78, radius: 12)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (product.originalPriceCents != null &&
                          product.originalPriceCents! > product.priceCents)
                        Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: Text(
                                formatDemoPrice(product.originalPriceCents!),
                                style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: GogdelyColors.mutedLight,
                                    fontSize: 12))),
                      Text(formatDemoPrice(product.priceCents),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (product.badge.isNotEmpty) ...[
                        const SizedBox(width: 7),
                        Text(product.badge,
                            style: const TextStyle(color: GogdelyColors.blue)),
                      ],
                    ]),
                  ])),
              const Icon(Icons.add_circle_outline,
                  color: GogdelyColors.blue, size: 27),
            ]),
          ),
        ),
      );
}

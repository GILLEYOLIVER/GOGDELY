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
  ('Restaurantes', Icons.restaurant, Color(0xFFFF8B25)),
  ('Mercado', Icons.shopping_basket, GogdelyColors.blue),
  ('Farmácia', Icons.medical_services, Color(0xFFDB3650)),
  ('Bebidas', Icons.local_drink, GogdelyColors.blue),
  ('Pet Shop', Icons.pets, GogdelyColors.blue),
  ('Lojas', Icons.storefront, Color(0xFFFF8B25)),
  ('Doces', Icons.cake, Color(0xFFB347B9)),
  ('Saúde e Beleza', Icons.spa, GogdelyColors.blue),
  ('Mais', Icons.more_horiz, GogdelyColors.blue),
];

class DemoStoreCard extends StatelessWidget {
  const DemoStoreCard(this.store,
      {super.key, required this.onTap, this.compact = false});
  final DemoStore store;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              SizedBox(
                  width: compact ? 64 : 82,
                  height: compact ? 64 : 82,
                  child: DemoPhoto(store.image,
                      height: compact ? 64 : 82, radius: 12)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(store.category,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('⭐ ${store.rating}  ·  ${store.eta}',
                        style: Theme.of(context).textTheme.labelSmall),
                  ])),
              const Icon(Icons.chevron_right, size: 18),
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(children: [
              SizedBox(
                  width: 66,
                  height: 66,
                  child: DemoPhoto(product.image, height: 66, radius: 10)),
              const SizedBox(width: 10),
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
                    if (product.category.isNotEmpty)
                      Text(product.category,
                          style: Theme.of(context).textTheme.labelSmall),
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
              const Icon(Icons.add_circle, color: GogdelyColors.blue),
            ]),
          ),
        ),
      );
}

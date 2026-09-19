import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';

class PromoBanner {
  const PromoBanner({
    required this.brand,
    required this.title,
    required this.offer,
    required this.detail,
    required this.code,
    required this.colors,
    required this.icon,
  });

  final String brand;
  final String title;
  final String offer;
  final String detail;
  final String code;
  final List<Color> colors;
  final IconData icon;
}

class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  static const double height = 190;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final _controller = PageController();
  int _index = 0;
  Timer? _timer;

  static const _items = [
    PromoBanner(
      brand: 'indofish',
      title: 'Weekend Mancing Deals',
      offer: 'Gratis',
      detail: 'Cirata · Jatiluhur · Gajah Mungkur\nUntuk event Sabtu - Minggu.',
      code: 'MANCINGBOSS',
      colors: [Color(0xFF0A3D32), Color(0xFF1FA86A)],
      icon: Icons.water_rounded,
    ),
    PromoBanner(
      brand: 'indofish',
      title: 'Sewa Lapak Hemat',
      offer: '20%',
      detail: 'Booking lapak lebih awal\nBerlaku untuk pemilik event aktif.',
      code: 'LAPAK20',
      colors: [Color(0xFF064536), Color(0xFF0B8A5B)],
      icon: Icons.storefront_rounded,
    ),
    PromoBanner(
      brand: 'indofish',
      title: 'Input Berat Cepat',
      offer: 'Live',
      detail: 'Operator catat hasil tangkapan\nRanking event update realtime.',
      code: 'BERATLIVE',
      colors: [Color(0xFF0F4C3A), Color(0xFF2BB673)],
      icon: Icons.monitor_weight_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _items.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: PromoBannerCarousel.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PromoCard(item: _items[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_items.length, (i) {
            final on = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: on ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: on ? AppTheme.primary : const Color(0xFFC9D4CE),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.item});

  final PromoBanner item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: item.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
            Positioned(
              right: -20,
              bottom: -30,
              child: Icon(item.icon, size: 170, color: Colors.white.withValues(alpha: 0.12)),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: Text('LIHAT DETAIL', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.brand, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 12)),
                  const Spacer(),
                  Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, height: 1.15)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Nikmati ', style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(999)),
                        child: Text(item.offer, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                      Text(' OFF', style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.detail, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 11, height: 1.35)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(10)),
                        child: const Text('Kode promo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(10)),
                        child: Text(item.code, style: const TextStyle(color: AppTheme.ink, fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

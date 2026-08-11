import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: size,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.local_shipping,
              size: size,
              color: Theme.of(context).colorScheme.primary,
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Fleet Control',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sistema de Control de Flotas',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

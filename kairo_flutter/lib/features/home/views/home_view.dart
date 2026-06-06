import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../auth/widgets/gradient_button.dart';
import '../../auth/widgets/kairo_logo.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const KairoLogo(size: 64),
              const SizedBox(height: 24),
              const Text(
                'Tu comunidad de fe',
                textAlign: TextAlign.center,
                style: TextStyle(color: KairoColors.darkText, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Comparte testimonios, pide oración y conecta con hermanos en Cristo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 16, height: 1.5),
              ),
              const Spacer(),
              GradientButton(label: 'Comenzar', onPressed: () => context.go('/auth/signup')),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/auth/signin'),
                child: const Text('Ya tengo cuenta', style: TextStyle(color: KairoColors.primary400)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/feed'),
                child: const Text('Explorar sin cuenta →', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

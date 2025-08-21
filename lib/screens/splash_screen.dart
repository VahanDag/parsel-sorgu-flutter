import 'dart:async';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;
  Timer? _textAnimationTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
    _navigateToHome();
  }

  void _initAnimations() {
    // Logo animasyonları
    _logoController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Metin animasyonları
    _textController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _textSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));
  }

  void _startAnimations() {
    _logoController.forward();

    // Logo animasyonu tamamlandıktan sonra metin animasyonunu başlat
    _textAnimationTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _textController.forward();
      }
    });
  }

  void _navigateToHome() {
    _navigationTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _textAnimationTimer?.cancel();
    _navigationTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.blue.shade50, Colors.white, Colors.blue.shade50]),
        ),
        child: Center(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo animasyonu
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Opacity(
                            opacity: _logoOpacityAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(color: const Color(0xFF90CAF9), blurRadius: 20, spreadRadius: 5)],
                              ),
                              child: // Icon yerine Image.asset kullanın
                                  ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/icon/icon.png',
                                  width: 80,
                                  height: 80,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Uygulama adı animasyonu
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _textSlideAnimation,
                          child: FadeTransition(
                            opacity: _textOpacityAnimation,
                            child: Column(
                              children: [
                                Text(
                                  'Parsel Sorgulama',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade800, letterSpacing: 1.2),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Gayrimenkul bilgilerinizi kolayca sorgulayın',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 60),

                    // Loading indicator
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _textOpacityAnimation,
                          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600), strokeWidth: 3),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Name at the bottom
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Vahan Dağ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

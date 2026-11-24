import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Versi web dibuka di laptop/proyektor: aplikasi tetap selebar ponsel di
/// tengah layar, bukan melebar seperti situs desktop. Di layar ponsel dan di
/// Android tidak mengubah apa pun.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child, this.enabled = kIsWeb});

  static const double lebarPonsel = 430;

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (!enabled || mq.size.width <= lebarPonsel) return child;
    return ColoredBox(
      color: const Color(0xFFECEAE6),
      child: Center(
        child: Container(
          width: lebarPonsel,
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24)],
          ),
          // layar di dalam bingkai menghitung tata letak dari lebar ponsel
          child: MediaQuery(
            data: mq.copyWith(size: Size(lebarPonsel, mq.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}

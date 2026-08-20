import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/global_header.dart';
import '../cubit/location_cubit.dart';
import 'location_picker_sheet.dart';

/// Full-page block shown in place of the shopping tabs whenever the last
/// serviceability check couldn't get an answer at all (network/timeout/
/// backend unreachable) — distinct from [NotServiceableScreen], which is
/// the authoritative "we checked, and you're outside every zone" case.
/// Never a dead end: offers both a same-address retry and the usual
/// "pick a different location" escape hatch.
class CheckFailedScreen extends StatelessWidget {
  const CheckFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationCubit, LocationState>(
      builder: (context, state) {
        final isRetrying = state is CheckingServiceability;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                const LocationHeader(title: "Couldn't fetch location"),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF3E0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.wifi_off_rounded,
                                color: Color(0xFFF57C00), size: 40),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Couldn't fetch your location",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "We couldn't check delivery availability. Please check your connection and try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isRetrying
                                  ? null
                                  : () => context
                                      .read<LocationCubit>()
                                      .retryServiceabilityCheck(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3DAA5C),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: isRetrying
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      "Try again",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => LocationPickerSheet.show(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE0E0E0)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                "Choose a different location",
                                style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _BrandFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF3DAA5C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.shopping_bag_rounded,
              color: Color(0xFF3DAA5C), size: 16),
        ),
        const SizedBox(height: 6),
        const Text(
          "Beeyo",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFBDBDBD),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/location_cubit.dart';
import 'location_picker_sheet.dart';

/// Full-page block shown in place of the shopping tabs (Home / Order Again /
/// Categories) whenever the bound location falls outside every delivery
/// zone — there's nothing servicable to browse, so don't pretend otherwise
/// by still rendering a product grid. Distinct from [NotDeliverableView],
/// which shows the same idea as embedded content *inside* the location
/// picker sheet's own BlocBuilder — this one is a standalone screen, so its
/// own CTA has to explicitly open that sheet rather than just changing
/// LocationCubit state and relying on something else being there to react.
class NotServiceableScreen extends StatelessWidget {
  const NotServiceableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationCubit, LocationState>(
      builder: (context, state) {
        final formattedAddress =
            state is NotDeliverable ? state.formattedAddress : null;
        final notifyListJoined =
            state is NotDeliverable ? state.notifyListJoined : false;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
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
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_off_rounded,
                          color: Color(0xFFE53935), size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Sorry, we don't deliver here yet",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedAddress != null
                          ? "$formattedAddress is outside our delivery area right now."
                          : "This location is outside our delivery area right now.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                        onPressed: () => LocationPickerSheet.show(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3DAA5C),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Choose a different location",
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
                        onPressed: notifyListJoined
                            ? null
                            : () =>
                                context.read<LocationCubit>().joinNotifyList(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          notifyListJoined
                              ? "We'll notify you ✓"
                              : "Notify me when available",
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

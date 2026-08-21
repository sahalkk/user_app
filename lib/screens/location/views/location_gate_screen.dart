import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/global_header.dart';
import '../cubit/location_cubit.dart';
import 'location_picker_sheet.dart';

/// Covers the shopping tabs for every [LocationState] that isn't [Bound],
/// [NotDeliverable], or [CheckFailed] (which get their own dedicated
/// screens) — i.e. still detecting, needs a permission decision, or nothing
/// picked yet. Product data should never render before we actually know
/// delivery works, so this is the "in between" placeholder rather than
/// letting MainWrapper fall through to real content by default.
///
/// Keeps the same [LocationHeader] the other gate screens (Not deliverable,
/// Check failed) use, rather than a bare centered page with no way back to
/// the "beeyo" shell — the location bar itself is a second, always-visible
/// way to open the picker alongside whatever action is offered below.
///
/// [PermissionPrimer] gets its own direct "Allow location access" action
/// here (wired straight to [LocationCubit.acknowledgePrimer]) rather than
/// making the user open the full picker sheet just to grant permission —
/// the whole point of this screen is that detection should happen with as
/// little friction as possible. Only the leftover "I declined / permission
/// is permanently denied / want to search instead" case falls back to
/// opening [LocationPickerSheet].
class LocationGateScreen extends StatelessWidget {
  const LocationGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationCubit, LocationState>(
      builder: (context, state) {
        final isBusy = state is PermissionChecking ||
            state is PermissionRequesting ||
            state is Resolving ||
            state is CheckingServiceability ||
            state is Confirming;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                const LocationHeader(title: "Select delivery location"),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: isBusy
                            ? _busyContent(state)
                            : state is PermissionPrimer
                                ? _primerContent(context)
                                : _manualEntryContent(context, state),
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

  List<Widget> _busyContent(LocationState state) {
    return [
      const CircularProgressIndicator(color: Color(0xFF3DAA5C)),
      const SizedBox(height: 20),
      Text(
        _busyLabelFor(state),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B6B6B),
        ),
      ),
    ];
  }

  String _busyLabelFor(LocationState state) {
    if (state is CheckingServiceability) {
      return "Checking delivery availability…";
    }
    return "Finding your location…";
  }

  List<Widget> _primerContent(BuildContext context) {
    return [
      Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.location_on_rounded,
            color: Color(0xFF3DAA5C), size: 40),
      ),
      const SizedBox(height: 20),
      const Text(
        "Enable location to get started",
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
        "We'll use it just to check what's deliverable near you — nothing gets saved until you actually place an order.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Color(0xFF6B6B6B),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => context.read<LocationCubit>().acknowledgePrimer(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3DAA5C),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text(
            "Allow location access",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.read<LocationCubit>().declinePrimer(),
        child: const Text(
          "Enter address manually",
          style:
              TextStyle(color: Color(0xFF6B6B6B), fontWeight: FontWeight.w600),
        ),
      ),
    ];
  }

  List<Widget> _manualEntryContent(BuildContext context, LocationState state) {
    final message = state is ManualEntry ? state.message : null;
    return [
      Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.location_on_rounded,
            color: Color(0xFF3DAA5C), size: 40),
      ),
      const SizedBox(height: 20),
      const Text(
        "Where should we deliver?",
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
        message ??
            "Select a delivery location to see what's available near you.",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Color(0xFF6B6B6B),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => LocationPickerSheet.show(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3DAA5C),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text(
            "Select delivery location",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    ];
  }
}

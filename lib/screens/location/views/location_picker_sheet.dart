import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/saved_address_model.dart';
import '../cubit/location_cubit.dart';
import 'map_pin_picker_screen.dart';
import 'not_deliverable_view.dart';

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<LocationCubit>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: const LocationPickerSheet(),
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<({String label, LatLng position})> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await context.read<LocationCubit>().searchAddress(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: BlocConsumer<LocationCubit, LocationState>(
            listener: (context, state) {
              // Binding succeeded — the header already reflects it, so
              // close the sheet automatically.
              if (state is Bound) Navigator.of(context).maybePop();
            },
            builder: (context, state) {
              if (state is PermissionPrimer) {
                return _PermissionPrimerView(scrollController: scrollController);
              }
              if (state is CheckingServiceability) {
                return const _CenteredLoader(label: "Checking delivery availability…");
              }
              if (state is NotDeliverable) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: const NotDeliverableView(),
                );
              }
              if (state is Confirming) {
                return _ConfirmAddressView(
                  state: state,
                  scrollController: scrollController,
                );
              }
              return _MainPickerView(
                scrollController: scrollController,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                results: _results,
                isSearching: _isSearching,
                isResolving: state is Resolving || state is PermissionChecking,
              );
            },
          ),
        );
      },
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  final String label;
  const _CenteredLoader({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF3DAA5C)),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF6B6B6B),
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Permission primer ("rationale before the OS dialog") ──────────────
class _PermissionPrimerView extends StatelessWidget {
  final ScrollController scrollController;
  const _PermissionPrimerView({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Color(0xFF3DAA5C), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            "Enable location for faster delivery",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll use your location to find your address and show you what's deliverable nearby. You can always enter it manually instead.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.read<LocationCubit>().acknowledgePrimer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3DAA5C),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Allow location access",
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<LocationCubit>().declinePrimer(),
            child: const Text("Enter address manually",
                style: TextStyle(color: Color(0xFF6B6B6B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Confirm a resolved/searched address before checking serviceability ──
class _ConfirmAddressView extends StatelessWidget {
  final Confirming state;
  final ScrollController scrollController;
  const _ConfirmAddressView({required this.state, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Confirm your location",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF3DAA5C)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.formattedAddress,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<LocationCubit>(),
                    child: MapPinPickerScreen(initialPosition: state.position),
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3DAA5C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Adjust pin on map & save",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<LocationCubit>().enterManualMode(),
            child: const Text("Back",
                style: TextStyle(color: Color(0xFF6B6B6B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Main picker: current location + search + saved addresses ──────────
class _MainPickerView extends StatelessWidget {
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<({String label, LatLng position})> results;
  final bool isSearching;
  final bool isResolving;

  const _MainPickerView({
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.results,
    required this.isSearching,
    required this.isResolving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text("Select delivery location",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
        const SizedBox(height: 16),

        // Search field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Search for area, street, or landmark",
              hintStyle: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E)),
              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF6B6B6B)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        if (isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF3DAA5C)))),
          ),

        if (results.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...results.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined,
                    color: Color(0xFF6B6B6B)),
                title: Text(r.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, color: Colors.black87)),
                onTap: () => context
                    .read<LocationCubit>()
                    .selectSearchResult(r.label, r.position),
              )),
        ] else ...[
          const SizedBox(height: 8),
          // Use current location
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: isResolving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF3DAA5C)))
                : const Icon(Icons.my_location_rounded, color: Color(0xFF3DAA5C)),
            title: const Text("Use my current location",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3DAA5C))),
            onTap: isResolving
                ? null
                : () => context.read<LocationCubit>().useCurrentLocation(),
          ),
          const Divider(height: 24, color: Color(0xFFE0E0E0)),

          const Text("Saved addresses",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B6B6B))),
          const SizedBox(height: 8),
          FutureBuilder<List<SavedAddressModel>>(
            future: context.read<LocationCubit>().getSavedAddresses(),
            builder: (context, snapshot) {
              final addresses = snapshot.data ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(
                      color: Color(0xFF3DAA5C), backgroundColor: Color(0xFFF0F0F0)),
                );
              }
              if (addresses.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("No saved addresses yet",
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E))),
                );
              }
              return Column(
                children: addresses
                    .map((a) => _SavedAddressTile(address: a))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_location_alt_outlined,
                color: Color(0xFF3DAA5C)),
            title: const Text("Add new address",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3DAA5C))),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<LocationCubit>(),
                  child: const MapPinPickerScreen(
                    initialPosition: LatLng(8.5241, 76.9366), // Trivandrum
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final SavedAddressModel address;
  const _SavedAddressTile({required this.address});

  IconData get _icon {
    switch (address.label) {
      case AddressLabel.home:
        return Icons.home_rounded;
      case AddressLabel.work:
        return Icons.work_rounded;
      case AddressLabel.other:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF0F0F0),
        child: Icon(_icon, color: const Color(0xFF6B6B6B), size: 18),
      ),
      title: Text(address.displayLabel,
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87)),
      subtitle: Text(address.formattedAddress,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF6B6B6B))),
      onTap: () => context.read<LocationCubit>().switchToSavedAddress(address),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/saved_address_model.dart';
import '../cubit/location_cubit.dart';

/// Full-screen "drop a pin" picker. The pin stays fixed at the screen
/// center — the map pans underneath it — which is what riders' navigation
/// ultimately keys off, so keep this exactly analogous to Swiggy/Zepto/
/// Blinkit rather than a draggable-marker pattern.
class MapPinPickerScreen extends StatefulWidget {
  final LatLng initialPosition;

  const MapPinPickerScreen({super.key, required this.initialPosition});

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  late final MapController _mapController;
  AddressLabel _label = AddressLabel.home;
  final _customLabelController = TextEditingController();
  final _landmarkController = TextEditingController();
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Kick off reverse geocoding for the initial center immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationCubit>().updatePinPosition(widget.initialPosition);
    });
  }

  @override
  void dispose() {
    _customLabelController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _onMapEventFinished() {
    setState(() => _isDragging = false);
    context
        .read<LocationCubit>()
        .updatePinPosition(_mapController.camera.center);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && !_isDragging) {
                  setState(() => _isDragging = true);
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _onMapEventFinished();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.beeyo.customer',
              ),
            ],
          ),

          // Fixed center pin
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_pin,
                    size: 44, color: Color(0xFF3DAA5C)),
              ),
            ),
          ),

          // Top bar: back + search
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Locate-me FAB
          Positioned(
            right: 16,
            bottom: 260,
            child: _RoundIconButton(
              icon: Icons.my_location_rounded,
              onTap: () async {
                final cubit = context.read<LocationCubit>();
                await cubit.useCurrentLocation();
                final state = cubit.state;
                if (state is Confirming) {
                  _mapController.move(state.position, 16);
                }
              },
            ),
          ),

          // Bottom confirm sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: _ConfirmSheet(
              isDragging: _isDragging,
              label: _label,
              onLabelChanged: (l) => setState(() => _label = l),
              customLabelController: _customLabelController,
              landmarkController: _landmarkController,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final bool isDragging;
  final AddressLabel label;
  final ValueChanged<AddressLabel> onLabelChanged;
  final TextEditingController customLabelController;
  final TextEditingController landmarkController;

  const _ConfirmSheet({
    required this.isDragging,
    required this.label,
    required this.onLabelChanged,
    required this.customLabelController,
    required this.landmarkController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<LocationCubit, LocationState>(
            builder: (context, state) {
              final address = isDragging
                  ? "Locating…"
                  : (state is Confirming ? state.formattedAddress : "…");
              return Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: Color(0xFF3DAA5C), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Label chips
          Wrap(
            spacing: 8,
            children: AddressLabel.values.map((l) {
              final selected = l == label;
              return ChoiceChip(
                label: Text(l.display),
                selected: selected,
                onSelected: (_) => onLabelChanged(l),
                selectedColor: const Color(0xFF3DAA5C),
                backgroundColor: const Color(0xFFF0F0F0),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: selected
                          ? const Color(0xFF3DAA5C)
                          : const Color(0xFFE0E0E0)),
                ),
              );
            }).toList(),
          ),

          if (label == AddressLabel.other) ...[
            const SizedBox(height: 12),
            _InputField(
              controller: customLabelController,
              hint: "Label (e.g. Friend's place)",
            ),
          ],

          const SizedBox(height: 12),
          _InputField(
            controller: landmarkController,
            hint: "Landmark / floor / gate instructions (helps riders)",
            maxLines: 2,
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: BlocBuilder<LocationCubit, LocationState>(
              builder: (context, state) {
                final isChecking = state is CheckingServiceability;
                final canConfirm = state is Confirming && !isDragging;

                return ElevatedButton(
                  onPressed: !canConfirm || isChecking
                      ? null
                      : () {
                          context.read<LocationCubit>().confirmAddress(
                                position: state.position,
                                formattedAddress: state.formattedAddress,
                                label: label,
                                customLabel: customLabelController.text.trim(),
                                landmark: landmarkController.text.trim(),
                              );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3DAA5C),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "Confirm & Save",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

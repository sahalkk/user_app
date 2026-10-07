import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../location/cubit/location_cubit.dart';

// TODO: flat placeholder until the backend prices delivery per zone/order.
const kDeliveryFee = 40.0;

const _kChevronDuration = Duration(milliseconds: 250);
const _green = Color(0xFF3DAA5C);
const _grey = Color(0xFF6B6B6B);

String formatRupees(double amount) => "₹${amount.toStringAsFixed(2)}";

/// How the customer pays. Only COD works today — the backend's order API has
/// no payment field yet, so UPI apps are listed as "Coming soon".
enum PaymentOption {
  cod("Cash on Delivery", "Cash", Icons.payments_rounded, isAvailable: true),
  gpay("Google Pay", "GPay", Icons.account_balance_wallet_rounded),
  phonePe("PhonePe", "PhonePe", Icons.phone_android_rounded),
  paytm("Paytm", "Paytm", Icons.account_balance_rounded),
  otherUpi("Other UPI apps", "UPI", Icons.qr_code_2_rounded);

  final String label;
  final String shortLabel;
  final IconData icon;
  final bool isAvailable;

  const PaymentOption(this.label, this.shortLabel, this.icon,
      {this.isAvailable = false});
}

/// Footer row that toggles a panel opening above it: leading icon, title
/// (+ optional subtitle), optional trailing value, and a chevron.
class _ExpandableRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color subtitleColor;
  final Widget? trailing;
  final bool expanded;
  final VoidCallback? onTap;

  const _ExpandableRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor = _grey,
    this.trailing,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: _green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: subtitleColor)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            _Chevron(expanded: expanded),
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  final bool expanded;
  const _Chevron({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: _kChevronDuration,
      child: const Icon(Icons.keyboard_arrow_up_rounded, color: _grey),
    );
  }
}

// ─────────────────────────────────────────────
//  Address
// ─────────────────────────────────────────────
class DeliverToStrip extends StatelessWidget {
  final bool expanded;
  final bool needsAddress;
  final VoidCallback? onTap;

  const DeliverToStrip({
    super.key,
    required this.expanded,
    required this.needsAddress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationCubit, LocationState>(
      builder: (context, state) {
        final String title;
        String? subtitle;
        if (expanded) {
          title = "Choose delivery address";
          if (needsAddress) subtitle = "Pick where this order should go";
        } else if (state is Bound) {
          // A saved address reads best by its label ("Home"); the ambient
          // pick from app start has no meaningful label, just an area.
          final a = state.address;
          final isSaved = a.recipientName.isNotEmpty;
          title = isSaved ? "Deliver to ${a.displayLabel}" : "Delivering to";
          subtitle = isSaved ? a.primaryAddressText : a.formattedAddress;
        } else if (state is CheckingServiceability) {
          title = "Checking delivery availability…";
        } else {
          title = "Choose delivery address";
        }

        return _ExpandableRow(
          icon: Icons.location_on_rounded,
          title: title,
          subtitle: subtitle,
          subtitleColor:
              needsAddress && expanded ? const Color(0xFFF57C00) : _grey,
          expanded: expanded,
          onTap: onTap,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Bill
// ─────────────────────────────────────────────
class BillSummaryRow extends StatelessWidget {
  final double toPay;
  final bool expanded;
  final VoidCallback? onTap;

  const BillSummaryRow({
    super.key,
    required this.toPay,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ExpandableRow(
      icon: Icons.receipt_long_rounded,
      title: expanded ? "Bill details" : "To pay",
      trailing: Text(formatRupees(toPay),
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black87)),
      expanded: expanded,
      onTap: onTap,
    );
  }
}

class BillBreakdown extends StatelessWidget {
  final double itemTotal;

  const BillBreakdown({super.key, required this.itemTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _BillLine("Item total", itemTotal),
          const SizedBox(height: 8),
          const _BillLine("Delivery fee", kDeliveryFee),
          const Divider(height: 20, color: Color(0xFFE0E0E0)),
          _BillLine("To pay", itemTotal + kDeliveryFee, isTotal: true),
        ],
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  final String title;
  final double amount;
  final bool isTotal;

  const _BillLine(this.title, this.amount, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Poppins',
      fontSize: isTotal ? 15 : 13,
      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
      color: isTotal ? Colors.black87 : _grey,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: style),
        Text(formatRupees(amount),
            style: isTotal ? style.copyWith(color: _green) : style),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Payment
// ─────────────────────────────────────────────

/// Compact "PAY USING / Cash ⌃" selector beside the Place order button.
class PaymentChip extends StatelessWidget {
  final PaymentOption option;
  final bool expanded;
  final VoidCallback? onTap;

  const PaymentChip({
    super.key,
    required this.option,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: expanded ? _green : const Color(0xFFE0E0E0),
              width: expanded ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(option.icon, size: 20, color: _green),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PAY USING",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF9E9E9E))),
                  Text(option.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ],
              ),
            ),
            _Chevron(expanded: expanded),
          ],
        ),
      ),
    );
  }
}

class PaymentOptionsPanel extends StatelessWidget {
  final PaymentOption selected;
  final ValueChanged<PaymentOption> onSelected;
  final double maxHeight;

  const PaymentOptionsPanel({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final option in PaymentOption.values)
            _PaymentRow(
              option: option,
              isSelected: option == selected,
              onTap: option.isAvailable ? () => onSelected(option) : null,
            ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentOption option;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PaymentRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = option.isAvailable;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF1F8F3) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? _green : const Color(0xFFE0E0E0),
                width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(option.icon, size: 20, color: isSelected ? _green : _grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(option.label,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
              ),
              if (enabled)
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isSelected ? _green : const Color(0xFFE0E0E0),
                  size: 22,
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Coming soon",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _grey)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

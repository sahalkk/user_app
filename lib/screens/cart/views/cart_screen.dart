import 'package:beeyo_customer/blocs/auth_bloc/auth_bloc.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_state.dart';
import 'package:beeyo_customer/screens/auth/views/login_screen.dart';
import 'package:beeyo_customer/screens/location/cubit/location_cubit.dart';
import 'package:beeyo_customer/screens/location/views/map_pin_picker_screen.dart';
import 'package:beeyo_customer/screens/main_wrapper.dart';
import 'package:beeyo_customer/screens/product_details/views/product_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../blocs/order_bloc/order_bloc.dart';
import '../../../blocs/order_bloc/order_event.dart';
import '../../../blocs/order_bloc/order_state.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/checkout_address_model.dart';
import '../widgets/checkout_footer_parts.dart';
import '../widgets/delivery_address_picker.dart';

const _kUndoDuration = Duration(seconds: 4);
const _kPanelDuration = Duration(milliseconds: 250);

/// What's expanded above the footer's rows — at most one at a time, so the
/// footer never grows by more than a single panel.
enum _FooterPanel { address, bill, payment }

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Items the user just swiped away — hidden locally while their "undo"
  // snackbar is showing. The actual CartBloc removal only happens once the
  // snackbar closes without the user tapping UNDO.
  final Set<String> _pendingDeleteIds = {};
  // Covers the address checks before PlaceOrder is dispatched; OrderBloc's
  // OrderPlacing covers the request itself.
  bool _isPreparing = false;
  _FooterPanel? _openPanel;
  // Set when Place order opened the address panel because no saved address
  // is bound yet.
  bool _needsAddress = false;
  // Only COD can be picked until payments are integrated.
  PaymentOption _payment = PaymentOption.cod;
  // Dark store serving the last bound address seen here — a switch that
  // lands on a different store gets a heads-up, since what's in stock can
  // differ between stores.
  String? _lastDarkStoreId;

  @override
  void initState() {
    super.initState();
    final state = context.read<LocationCubit>().state;
    if (state is Bound) _lastDarkStoreId = state.darkStoreId;
  }

  void _setPanel(_FooterPanel? panel, {bool needsAddress = false}) {
    setState(() {
      _openPanel = panel;
      _needsAddress = panel == _FooterPanel.address && needsAddress;
    });
  }

  Future<void> _togglePanel(_FooterPanel panel) async {
    if (_openPanel == panel) {
      _setPanel(null);
      return;
    }
    // Guests have no saved addresses to pick from — log in first.
    if (panel == _FooterPanel.address &&
        (!await _ensureLoggedIn() || !mounted)) {
      return;
    }
    _setPanel(panel);
  }

  /// True once the user is logged in, sending guests through LoginScreen
  /// first (false if they back out of it).
  Future<bool> _ensureLoggedIn() async {
    final authBloc = context.read<AuthBloc>();

    // If the AuthBloc is still in the initial state (e.g. after a hot
    // restart) wait briefly for it to initialize so we do not incorrectly
    // force the user to the login screen on first tap.
    if (authBloc.state is AuthInitial) {
      try {
        await authBloc.stream
            .firstWhere((s) => s is! AuthInitial)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // ignore timeout and re-check below
      }
      if (!mounted) return false;
    }
    if (authBloc.state is AuthAuthenticated) return true;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    // They may have pressed "Back" and still be a guest.
    return mounted && authBloc.state is AuthAuthenticated;
  }

  /// Places the order against LocationCubit's bound address, picked in the
  /// footer's inline picker. When the bound location isn't a saved address
  /// — a searched area or GPS fix, with no flat number or recipient — or
  /// nothing is saved yet, the add-address wizard opens on that spot so the
  /// user confirms the pin and fills in details, then the order goes out.
  /// With nothing bound at all, the picker opens instead.
  Future<void> _placeOrder() async {
    if (!await _ensureLoggedIn() || !mounted) return;
    final cubit = context.read<LocationCubit>();
    setState(() => _isPreparing = true);
    var ready = false;
    try {
      final saved = await cubit.getSavedAddresses();
      if (!mounted) return;
      final bound = DeliveryAddressPicker.boundSaved(cubit.state, saved);
      if (saved.isEmpty || (bound == null && cubit.state is Bound)) {
        ready = await MapPinPickerScreen.openForNewAddress(context);
      } else if (bound == null) {
        _setPanel(_FooterPanel.address, needsAddress: true);
      } else if (DeliveryAddressPicker.hasContact(bound)) {
        ready = true;
      } else {
        ready = await DeliveryAddressPicker.completeContact(context, bound);
      }
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
    if (!ready || !mounted) return;

    // Re-read: the add/complete steps above may have bound a new address.
    final location = cubit.state;
    final cart = context.read<CartBloc>().state;
    if (location is! Bound || cart is! CartLoaded) return;
    _setPanel(null);
    final address = location.address;
    context.read<OrderBloc>().add(PlaceOrder(
          items: List.from(cart.items),
          totalAmount: cart.totalAmount + kDeliveryFee,
          address: CheckoutAddressModel(
            recipientName: address.recipientName,
            recipientPhone: address.recipientPhone,
            address: address,
          ),
        ));
  }

  void _onOrderStateChanged(BuildContext context, OrderState state) {
    if (state is OrderPlaceError) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.message)));
      return;
    }
    if (state is! OrderPlaced) return;

    context.read<CartBloc>().add(ClearCart());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 16),
            Text("Order Placed!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Your order has been received successfully.",
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    // A fresh stack on the Orders tab — back from there shouldn't land on
    // the now-empty cart.
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => const MainWrapper(initialIndex: 3)),
        (_) => false,
      );
    });
  }

  void _onLocationChanged(BuildContext context, LocationState state) {
    if (state is! Bound) return;
    final previous = _lastDarkStoreId;
    _lastDarkStoreId = state.darkStoreId;
    if (previous != null &&
        state.darkStoreId != null &&
        state.darkStoreId != previous) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            "This address is served by a different store — item availability may change."),
      ));
    }
  }

  void _handleSwipeDelete(CartItemModel cartItem) {
    setState(() => _pendingDeleteIds.add(cartItem.product.id));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            duration: _kUndoDuration,
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF222222),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            content: _UndoSnackBarContent(
              message: "${cartItem.product.title} removed",
              duration: _kUndoDuration,
            ),
            action: SnackBarAction(
              label: "UNDO",
              textColor: const Color(0xFF3DAA5C),
              onPressed: () {
                if (!mounted) return;
                setState(() => _pendingDeleteIds.remove(cartItem.product.id));
              },
            ),
          ),
        )
        .closed
        .then((reason) {
      if (!mounted) return;
      if (reason != SnackBarClosedReason.action) {
        // Wasn't undone — commit the removal for real.
        context.read<CartBloc>().add(RemoveFromCart(cartItem.product.id));
      }
      setState(() => _pendingDeleteIds.remove(cartItem.product.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<OrderBloc, OrderState>(listener: _onOrderStateChanged),
        BlocListener<LocationCubit, LocationState>(
            listener: _onLocationChanged),
      ],
      child: PopScope(
        // Back closes an open footer panel before it leaves the cart.
        canPop: _openPanel == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _setPanel(null);
        },
        child: _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: const Text("My Cart",
            style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.black87,
                fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is! CartLoaded || state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined,
                        size: 40, color: Color(0xFFBDBDBD)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Your cart is empty",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          color: Color(0xFF6B6B6B))),
                ],
              ),
            );
          }

          final visibleItems = state.items
              .where((item) => !_pendingDeleteIds.contains(item.product.id))
              .toList();

          return Column(
            children: [
              // 1. List of Items, dimmed while the address picker is open
              Expanded(
                child: Stack(
                  children: [
                    ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final cartItem = visibleItems[index];
                        return _CartItemCard(
                          key: ValueKey(cartItem.product.id),
                          cartItem: cartItem,
                          onSwipeDelete: () => _handleSwipeDelete(cartItem),
                        );
                      },
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: _openPanel == null,
                        child: GestureDetector(
                          onTap: () => _setPanel(null),
                          child: AnimatedOpacity(
                            opacity: _openPanel == null ? 0 : 1,
                            duration: _kPanelDuration,
                            child: const ColoredBox(color: Color(0x33000000)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Checkout Section — each row's panel grows upward from it
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  border: const Border(
                      top: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: BlocBuilder<OrderBloc, OrderState>(
                    builder: (context, orderState) {
                      final busy = _isPreparing || orderState is OrderPlacing;
                      final panelMaxHeight =
                          MediaQuery.sizeOf(context).height * 0.45;
                      final toPay = state.totalAmount + kDeliveryFee;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DeliverToStrip(
                            expanded: _openPanel == _FooterPanel.address,
                            needsAddress: _needsAddress,
                            onTap: busy
                                ? null
                                : () => _togglePanel(_FooterPanel.address),
                          ),
                          _panelSlot(
                            _FooterPanel.address,
                            () => DeliveryAddressPicker(
                              maxHeight: panelMaxHeight,
                              onResolved: () => _setPanel(null),
                            ),
                          ),
                          BillSummaryRow(
                            toPay: toPay,
                            expanded: _openPanel == _FooterPanel.bill,
                            onTap: () => _togglePanel(_FooterPanel.bill),
                          ),
                          _panelSlot(
                            _FooterPanel.bill,
                            () => BillBreakdown(itemTotal: state.totalAmount),
                          ),
                          _panelSlot(
                            _FooterPanel.payment,
                            () => PaymentOptionsPanel(
                              selected: _payment,
                              maxHeight: panelMaxHeight,
                              onSelected: (option) {
                                _payment = option;
                                _setPanel(null);
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: PaymentChip(
                                  option: _payment,
                                  expanded: _openPanel == _FooterPanel.payment,
                                  onTap: busy
                                      ? null
                                      : () =>
                                          _togglePanel(_FooterPanel.payment),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: busy ? null : _placeOrder,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      disabledBackgroundColor:
                                          Theme.of(context).primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                    child: busy
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : FittedBox(
                                            child: Text(
                                              "Place order · ${formatRupees(toPay)}",
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  /// [panel]'s content while it's the open one; collapses smoothly to
  /// nothing otherwise. Built lazily so closed panels (e.g. the address
  /// list, which fetches on init) don't exist at all.
  Widget _panelSlot(_FooterPanel panel, Widget Function() build) {
    return AnimatedSize(
      duration: _kPanelDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: _openPanel == panel
          ? Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: build(),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

// ─────────────────────────────────────────────
//  Swipeable cart item card
// ─────────────────────────────────────────────
class _CartItemCard extends StatelessWidget {
  final CartItemModel cartItem;
  final VoidCallback onSwipeDelete;

  const _CartItemCard({
    super.key,
    required this.cartItem,
    required this.onSwipeDelete,
  });

  @override
  Widget build(BuildContext context) {
    final itemTotal = cartItem.product.priceValue * cartItem.quantity;

    // Fresh fade + scale entrance every time this widget is (re)inserted
    // into the tree — plays on first load, and again if the user hits UNDO.
    return TweenAnimationBuilder<double>(
      key: ValueKey('${cartItem.product.id}-entrance'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.92 + (0.08 * value), child: child),
      ),
      child: Dismissible(
        key: ValueKey(cartItem.product.id),
        direction: DismissDirection.horizontal,
        background: _swipeBackground(alignment: Alignment.centerLeft),
        secondaryBackground: _swipeBackground(alignment: Alignment.centerRight),
        onDismissed: (_) => onSwipeDelete(),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProductDetailsScreen(product: cartItem.product),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              children: [
                // --- Image ---
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(cartItem.product.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // --- Details Column ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartItem.product.title,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cartItem.product.unit.isNotEmpty
                            ? cartItem.product.unit
                            : "1 Unit",
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFF6B6B6B),
                            fontSize: 11),
                      ),

                      const SizedBox(height: 12),

                      // Price and Quantity Controls Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // --- PRICE + strikethrough "original" price ---
                          // TODO: hardcoded 20% markup as a stand-in for a
                          // real discount/original price until the backend
                          // adds one (matches ProductCard's placeholder).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "₹${itemTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.black87),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "₹${(itemTotal * 1.2).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF9E9E9E),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),

                          // --- QUANTITY CONTROLS ---
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3DAA5C),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (cartItem.quantity > 1) {
                                      context.read<CartBloc>().add(
                                          UpdateCartItemQuantity(
                                              cartItem.product.id,
                                              cartItem.quantity - 1));
                                    } else {
                                      context.read<CartBloc>().add(
                                          RemoveFromCart(cartItem.product.id));
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Icon(Icons.remove_rounded,
                                        size: 15, color: Colors.white),
                                  ),
                                ),
                                Text(
                                  "${cartItem.quantity}",
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white),
                                ),
                                InkWell(
                                  onTap: () {
                                    context.read<CartBloc>().add(
                                        UpdateCartItemQuantity(
                                            cartItem.product.id,
                                            cartItem.quantity + 1));
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Icon(Icons.add_rounded,
                                        size: 15, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBackground({required Alignment alignment}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Icon(Icons.delete_rounded, color: Color(0xFFE53935)),
    );
  }
}

// ─────────────────────────────────────────────
//  Snackbar content with an animated countdown bar
// ─────────────────────────────────────────────
class _UndoSnackBarContent extends StatelessWidget {
  final String message;
  final Duration duration;

  const _UndoSnackBarContent({
    required this.message,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: duration,
            curve: Curves.linear,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF3DAA5C)),
            ),
          ),
        ),
      ],
    );
  }
}

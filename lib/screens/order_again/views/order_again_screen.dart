import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../blocs/auth_bloc/auth_bloc.dart';
import '../../../blocs/auth_bloc/auth_state.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../blocs/order_bloc/order_bloc.dart';
import '../../../blocs/order_bloc/order_event.dart';
import '../../../blocs/order_bloc/order_state.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/widgets/floating_cart_banner.dart';
import '../../../shared/widgets/global_header.dart';
import '../../../shared/widgets/product_grid.dart';
import '../../home/blocs/home_bloc.dart';

const _green = Color(0xFF3DAA5C);
const _grey = Color(0xFF6B6B6B);
const _border = Color(0xFFE0E0E0);
const _surface = Color(0xFFF5F5F5);
const _red = Color(0xFFE53935);
const _amber = Color(0xFFF59E0B);

const _maxOrdersShown = 10;
const _maxUsualsShown = 9;

/// An order line matched against the live catalog. Order history only
/// carries productId/quantity/price, so name, image and current price come
/// from [HomeLoaded.allProducts]; anything no longer in the catalog is
/// shown but can't be re-added.
class _ResolvedItem {
  final ProductModel product;
  final int quantity;
  final bool available;

  const _ResolvedItem(this.product, this.quantity, this.available);
}

class OrderAgainScreen extends StatefulWidget {
  const OrderAgainScreen({super.key});

  @override
  State<OrderAgainScreen> createState() => _OrderAgainScreenState();
}

class _OrderAgainScreenState extends State<OrderAgainScreen> {
  // OrderBloc is shared with checkout, so its state passes through
  // OrderPlacing/OrderPlaced — keep the last loaded list here so the
  // carousel doesn't blank out while an order is being placed.
  List<OrderModel>? _orders;

  @override
  void initState() {
    super.initState();
    final state = context.read<OrderBloc>().state;
    if (state is OrderLoaded) _orders = state.orders;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<OrderBloc, OrderState>(
          listener: (context, state) {
            if (state is OrderLoaded) {
              setState(() => _orders = state.orders);
            } else if (state is OrderPlaced) {
              context.read<OrderBloc>().add(const LoadOrders(silent: true));
            }
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              (previous is AuthAuthenticated) != (current is AuthAuthenticated),
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              context.read<OrderBloc>().add(const LoadOrders(silent: true));
            } else {
              setState(() => _orders = null);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const FloatingCartBanner(),
        body: SafeArea(
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, homeState) {
              if (homeState is HomeLoading) {
                return const Center(
                    child: CircularProgressIndicator(color: _green));
              }
              if (homeState is! HomeLoaded) return const SizedBox();
              return _buildContent(context, homeState);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeLoaded homeState) {
    final isLoggedIn = context.watch<AuthBloc>().state is AuthAuthenticated;
    final orderState = context.watch<OrderBloc>().state;
    final catalog = {for (final p in homeState.allProducts) p.id: p};

    final orders = isLoggedIn
        ? ([...?_orders]..sort((a, b) => b.date.compareTo(a.date)))
        : <OrderModel>[];
    final isLoading = isLoggedIn &&
        _orders == null &&
        (orderState is OrderInitial || orderState is OrderLoading);

    final usuals = _usualProducts(orders, catalog);
    final usualIds = usuals.map((p) => p.id).toSet();
    final bestsellers = homeState.allProducts
        .where((p) => !usualIds.contains(p.id))
        .take(6)
        .toList();

    return RefreshIndicator(
      color: _green,
      onRefresh: () async {
        if (isLoggedIn) {
          context.read<OrderBloc>().add(const LoadOrders(silent: true));
        }
      },
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: LocationHeader(title: "ORDER AGAIN"),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyHeaderDelegate(
              height: 65,
              child: const StickySearchBar(),
            ),
          ),
          if (isLoading)
            const SliverToBoxAdapter(child: _OrdersSkeleton())
          else if (orders.isEmpty)
            const SliverToBoxAdapter(child: _EmptyState())
          else ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: "Your past orders",
                subtitle: "Reorder everything in a single tap",
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 206,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  itemCount: orders.length.clamp(0, _maxOrdersShown),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _PastOrderCard(
                      order: order,
                      items: _resolve(order, catalog),
                    );
                  },
                ),
              ),
            ),
            if (usuals.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  title: "Your usuals",
                  subtitle: "Things you buy most often",
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 14),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: ProductGrid(products: usuals, crossAxisCount: 3),
                ),
              ),
            ],
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: Divider(thickness: 6, height: 6, color: _surface),
              ),
            ),
          ],
          if (bestsellers.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(
                title: "Bestsellers",
                padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: ProductGrid(products: bestsellers, crossAxisCount: 3),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  /// Distinct catalog products from past orders, most frequently ordered
  /// first (ties broken by most recent order).
  List<ProductModel> _usualProducts(
      List<OrderModel> orders, Map<String, ProductModel> catalog) {
    final counts = <String, int>{};
    final lastOrdered = <String, DateTime>{};
    for (final order in orders) {
      if (order.status == 'CANCELLED') continue;
      for (final id in order.items.map((i) => i.product.id).toSet()) {
        if (!catalog.containsKey(id)) continue;
        counts[id] = (counts[id] ?? 0) + 1;
        final last = lastOrdered[id];
        if (last == null || order.date.isAfter(last)) {
          lastOrdered[id] = order.date;
        }
      }
    }
    final ids = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0
            ? byCount
            : lastOrdered[b]!.compareTo(lastOrdered[a]!);
      });
    return ids.take(_maxUsualsShown).map((id) => catalog[id]!).toList();
  }
}

List<_ResolvedItem> _resolve(
    OrderModel order, Map<String, ProductModel> catalog) {
  return order.items.map((item) {
    final live = catalog[item.product.id];
    return _ResolvedItem(live ?? item.product, item.quantity, live != null);
  }).toList();
}

double _orderTotal(OrderModel order) {
  if (order.totalAmount > 0) return order.totalAmount;
  return order.items.fold(0.0, (sum, item) => sum + item.totalPrice);
}

String _formatPrice(double value) => value == value.roundToDouble()
    ? "₹${value.toStringAsFixed(0)}"
    : "₹${value.toStringAsFixed(2)}";

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = DateFormat('h:mm a').format(local);
  final diff = today.difference(day).inDays;
  if (diff == 0) return "Today, $time";
  if (diff == 1) return "Yesterday, $time";
  if (local.year == now.year) return DateFormat('d MMM, h:mm a').format(local);
  return DateFormat('d MMM yyyy').format(local);
}

/// Adds every still-available item of a past order to the cart at its
/// original quantity, and tells the user what happened.
void _reorder(BuildContext context, List<_ResolvedItem> items) {
  final available = items.where((i) => i.available).toList();
  final skipped = items.length - available.length;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

  String message;
  if (available.isEmpty) {
    message = "These items are no longer available";
  } else {
    context.read<CartBloc>().add(AddItemsToCart(available
        .map((i) =>
            CartItemModel(id: '', product: i.product, quantity: i.quantity))
        .toList()));
    final count = available.length;
    message = "Added $count item${count == 1 ? '' : 's'} to your cart"
        "${skipped > 0 ? ' · $skipped unavailable' : ''}";
  }

  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF222222),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // Lifted clear of the floating "View Cart" banner, which appears as
    // soon as the cart has items.
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    duration: const Duration(seconds: 2),
    content: Row(
      children: [
        Icon(
            available.isEmpty
                ? Icons.info_outline_rounded
                : Icons.check_circle_rounded,
            color: available.isEmpty ? _amber : _green,
            size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  ));
}

// ─────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsets padding;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: _grey)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Past order card (horizontal carousel)
// ─────────────────────────────────────────────
class _PastOrderCard extends StatelessWidget {
  final OrderModel order;
  final List<_ResolvedItem> items;

  const _PastOrderCard({required this.order, required this.items});

  @override
  Widget build(BuildContext context) {
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final names = items.map((i) => i.product.title).toList();
    final summary = names.length <= 2
        ? names.join(" & ")
        : "${names.take(2).join(", ")} & ${names.length - 2} more";
    final hasAvailable = items.any((i) => i.available);

    return GestureDetector(
      onTap: () => _OrderDetailsSheet.show(context, order, items),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_dateLabel(order.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            _ThumbStrip(items: items),
            const SizedBox(height: 10),
            Text(summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: _grey)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatPrice(_orderTotal(order)),
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87)),
                      Text("$itemCount item${itemCount == 1 ? '' : 's'}",
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _grey)),
                    ],
                  ),
                ),
                _ReorderButton(
                  enabled: hasAvailable,
                  onTap: () => _reorder(context, items),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ReorderButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? _green : _border,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.replay_rounded,
                  size: 16, color: enabled ? Colors.white : _grey),
              const SizedBox(width: 6),
              Text("Reorder",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: enabled ? Colors.white : _grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.toUpperCase()) {
      'DELIVERED' => ("Delivered", _green),
      'CANCELLED' => ("Cancelled", _red),
      'RETURNED' => ("Returned", _red),
      'SHIPPED' => ("On the way", _amber),
      'PAID' => ("Confirmed", _amber),
      'PROCESSING' => ("Processing", _amber),
      _ => ("Placed", _amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

/// Up to four product thumbnails in a row; when there are more items the
/// last slot becomes a "+N" tile.
class _ThumbStrip extends StatelessWidget {
  final List<_ResolvedItem> items;

  const _ThumbStrip({required this.items});

  static const _size = 52.0;
  static const _slots = 4;

  @override
  Widget build(BuildContext context) {
    final overflow = items.length > _slots;
    final shown = items.take(overflow ? _slots - 1 : _slots).toList();
    return Row(
      children: [
        for (final item in shown) ...[
          _ProductThumb(
              product: item.product, size: _size, dimmed: !item.available),
          const SizedBox(width: 8),
        ],
        if (overflow)
          Container(
            width: _size,
            height: _size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text("+${items.length - shown.length}",
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _green)),
          ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final ProductModel product;
  final double size;
  final bool dimmed;

  const _ProductThumb({
    required this.product,
    required this.size,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(Icons.shopping_basket_outlined,
        color: const Color(0xFFBDBDBD), size: size * 0.45);
    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: product.imageUrl.isEmpty
            ? placeholder
            : Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Order details bottom sheet
// ─────────────────────────────────────────────
class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;
  final List<_ResolvedItem> items;
  final VoidCallback onReorder;

  const _OrderDetailsSheet({
    required this.order,
    required this.items,
    required this.onReorder,
  });

  // [context] is the screen's, not the sheet's — the reorder runs after the
  // sheet has closed, so it must use a context that's still mounted.
  static void show(
      BuildContext context, OrderModel order, List<_ResolvedItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      builder: (_) => _OrderDetailsSheet(
        order: order,
        items: items,
        onReorder: () => _reorder(context, items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = items.where((i) => i.available).toList();
    final shortId = order.id.length > 8
        ? order.id.substring(order.id.length - 8)
        : order.id;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Order #${shortId.toUpperCase()}",
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                      Text(_dateLabel(order.date),
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: _grey)),
                    ],
                  ),
                ),
                _StatusChip(status: order.status),
              ],
            ),
          ),
          const Divider(height: 24, color: _border),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                return Row(
                  children: [
                    _ProductThumb(
                        product: item.product,
                        size: 48,
                        dimmed: !item.available),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(
                              item.available
                                  ? "Qty ${item.quantity} · ${_formatPrice(item.product.priceValue)} each"
                                  : "No longer available",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: item.available ? _grey : _red)),
                        ],
                      ),
                    ),
                    if (item.available)
                      Text(
                          _formatPrice(
                              item.product.priceValue * item.quantity),
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: available.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        onReorder();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _border,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                label: Text(
                  available.isEmpty
                      ? "Items unavailable"
                      : "Add ${available.length} item${available.length == 1 ? '' : 's'} to cart",
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Empty + loading states
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 32, 16, 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: _green),
            SizedBox(height: 16),
            Text("Reordering will be easy",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            SizedBox(height: 8),
            Text(
                "Items you order will show up here so you can buy them again easily.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: _grey,
                    fontSize: 13,
                    height: 1.4)),
            SizedBox(height: 24),
            Divider(thickness: 1, color: _border),
          ],
        ),
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(8)),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(160, 20),
          const SizedBox(height: 16),
          SizedBox(
            height: 194,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Container(
                width: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(120, 14),
                    const SizedBox(height: 14),
                    Row(children: [
                      for (var i = 0; i < 4; i++) ...[
                        bar(52, 52),
                        const SizedBox(width: 8),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    bar(180, 12),
                    const Spacer(),
                    Row(children: [
                      bar(60, 20),
                      const Spacer(),
                      bar(96, 36),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

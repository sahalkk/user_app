import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/auth_bloc/auth_bloc.dart';
import '../../../blocs/auth_bloc/auth_state.dart';
import '../../../blocs/order_bloc/order_bloc.dart';
import '../../../blocs/order_bloc/order_event.dart';
import '../../../blocs/order_bloc/order_state.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/order_status.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/utils/order_items_resolver.dart';
import '../../../shared/widgets/order_status_chip.dart';
import '../../home/blocs/home_bloc.dart';

const _green = Color(0xFF3DAA5C);
const _grey = Color(0xFF6B6B6B);
const _border = Color(0xFFE8E8E8);
const _surface = Color(0xFFF5F5F5);
const _background = Color(0xFFF7F8FA);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with WidgetsBindingObserver {
  // No push infra (no WebSocket/notification channel) behind order status
  // yet, so this is a short poll instead — good enough for a status tag
  // that only changes a few times over an order's life. Paused whenever the
  // app isn't in the foreground so it doesn't spend battery/data unseen.
  // Each poll also rebuilds the list, which is what moves a delivered order
  // from Active to Past once its linger window has passed.
  static const _pollInterval = Duration(seconds: 12);
  Timer? _pollTimer;

  // OrderBloc is shared with checkout, so its state passes through
  // OrderPlacing/OrderPlaced — keep the last loaded list here so the page
  // doesn't flash "No orders yet" while an order is being placed.
  List<OrderModel>? _orders;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = context.read<OrderBloc>().state;
    if (state is OrderLoaded) _orders = state.orders;
    context.read<OrderBloc>().add(LoadOrders());
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      context.read<OrderBloc>().add(const LoadOrders(silent: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Catch up on anything that changed while backgrounded, then resume
      // the regular poll cadence.
      context.read<OrderBloc>().add(const LoadOrders(silent: true));
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final bloc = context.read<OrderBloc>();
    final done =
        bloc.stream.firstWhere((s) => s is OrderLoaded || s is OrderLoadError);
    bloc.add(const LoadOrders(silent: true));
    await done.timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<OrderBloc, OrderState>(
          listener: (context, state) {
            if (state is OrderLoaded) {
              setState(() {
                _orders = state.orders;
                _loadError = null;
              });
            } else if (state is OrderLoadError) {
              setState(() => _loadError = state.message);
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
        backgroundColor: _background,
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final orderState = context.watch<OrderBloc>().state;
    final homeState = context.watch<HomeBloc>().state;
    final catalog = homeState is HomeLoaded
        ? {for (final p in homeState.allProducts) p.id: p}
        : <String, ProductModel>{};

    final orders = [...?_orders]..sort((a, b) => b.date.compareTo(a.date));
    final active = orders.where((o) => o.isActive).toList();
    final past = orders.where((o) => !o.isActive).toList();

    final isLoading = _orders == null &&
        _loadError == null &&
        (orderState is OrderInitial || orderState is OrderLoading);

    final Widget content;
    if (isLoading) {
      content = const SliverToBoxAdapter(child: _OrdersSkeleton());
    } else if (_orders == null && _loadError != null) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorState(
          message: _loadError!,
          onRetry: () => context.read<OrderBloc>().add(LoadOrders()),
        ),
      );
    } else if (orders.isEmpty) {
      content = const SliverFillRemaining(
          hasScrollBody: false, child: _EmptyState());
    } else {
      content = SliverMainAxisGroup(slivers: [
        if (active.isNotEmpty) ...[
          _SectionHeader(
            title: "Active now",
            trailing: _CountBadge(count: active.length, color: _green),
            live: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: active.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final order = active[index];
                return _ActiveOrderCard(
                  order: order,
                  items: resolveOrderItems(order, catalog),
                );
              },
            ),
          ),
        ],
        if (past.isNotEmpty) ...[
          _SectionHeader(
            title: "Past orders",
            trailing: _CountBadge(count: past.length, color: _grey),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _PastOrdersGroup(orders: past, catalog: catalog),
            ),
          ),
        ],
      ]);
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(activeCount: active.length)),
          content,
          const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Header + section headers
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int activeCount;

  const _Header({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final subtitle = activeCount == 0
        ? "Track your past & active orders"
        : "$activeCount order${activeCount == 1 ? '' : 's'} in progress";
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your Orders",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, color: _grey)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;
  final bool live;

  const _SectionHeader({
    required this.title,
    required this.trailing,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Row(
          children: [
            if (live) ...[
              const _PulsingDot(color: _green, size: 10),
              const SizedBox(width: 8),
            ],
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text("$count",
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ─────────────────────────────────────────────
//  Active order card
// ─────────────────────────────────────────────
String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return "just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
  if (diff.inHours < 24) return "${diff.inHours} h ago";
  return orderDateLabel(time);
}

String _stageMessage(OrderStage stage) => switch (stage) {
      OrderStage.placed =>
        "We've received your order and are getting it ready.",
      OrderStage.onDelivery =>
        "Your order has been picked up and is on its way to you.",
      OrderStage.delivered => "Your order has arrived. Enjoy!",
      OrderStage.cancelled => "This order was cancelled.",
    };

class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final List<ResolvedOrderItem> items;

  const _ActiveOrderCard({required this.order, required this.items});

  @override
  Widget build(BuildContext context) {
    final stage = order.stage;
    final color = stage.color;
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final timeLine = stage == OrderStage.delivered
        ? "Delivered ${_relativeTime(order.updatedAt ?? order.date)}"
        : "Placed ${_relativeTime(order.date)}";

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => _OrderDetailsSheet.show(context, order, items),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status band
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                color: color.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(stage.icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.stageLabel,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                          const SizedBox(height: 1),
                          Text(_stageMessage(stage),
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  height: 1.35,
                                  color: Color(0xFF444444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _OrderStepper(stage: stage),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Divider(height: 1, color: _border),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _ThumbStrip(items: items)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatPrice(orderTotal(order)),
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87)),
                        Text("$itemCount item${itemCount == 1 ? '' : 's'}",
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _grey)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text("#${shortOrderId(order)} · $timeLine",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _grey)),
                    ),
                    const Text("Details",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _green)),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: _green),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Order placed → On delivery → Delivered.
class _OrderStepper extends StatelessWidget {
  final OrderStage stage;

  const _OrderStepper({required this.stage});

  static const _labels = ["Order placed", "On delivery", "Delivered"];

  @override
  Widget build(BuildContext context) {
    final current = stage.step;
    final color = stage.color;
    // Once delivered there's nothing left in progress — every step is done.
    final allDone = stage == OrderStage.delivered;

    Widget dot(int i) {
      if (i < current || allDone) {
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        );
      }
      if (i == current) return _PulsingDot(color: color, size: 22);
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _border, width: 2),
        ),
      );
    }

    Widget line(int i) => Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i < current || allDone ? color : _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );

    Widget label(int i, TextAlign align) {
      final reached = i <= current;
      return Expanded(
        child: Text(_labels[i],
            textAlign: align,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                color: reached ? Colors.black87 : const Color(0xFFAAAAAA))),
      );
    }

    return Column(
      children: [
        Row(children: [dot(0), line(0), dot(1), line(1), dot(2)]),
        const SizedBox(height: 6),
        Row(children: [
          label(0, TextAlign.left),
          label(1, TextAlign.center),
          label(2, TextAlign.right),
        ]),
      ],
    );
  }
}

/// A solid dot with a soft ring that breathes outward — marks the step an
/// order is currently on, and the "Active now" header.
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, required this.size});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * (0.55 + 0.45 * t),
                height: size * (0.55 + 0.45 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: size * 0.5,
                height: size * 0.5,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Past orders
// ─────────────────────────────────────────────
class _PastOrdersGroup extends StatelessWidget {
  final List<OrderModel> orders;
  final Map<String, ProductModel> catalog;

  const _PastOrdersGroup({required this.orders, required this.catalog});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < orders.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1, indent: 76, endIndent: 16, color: _border),
              _PastOrderTile(
                order: orders[i],
                items: resolveOrderItems(orders[i], catalog),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PastOrderTile extends StatelessWidget {
  final OrderModel order;
  final List<ResolvedOrderItem> items;

  const _PastOrderTile({required this.order, required this.items});

  @override
  Widget build(BuildContext context) {
    final names = items.map((i) => i.product.title).toList();
    final summary = names.isEmpty
        ? "Order #${shortOrderId(order)}"
        : names.length <= 2
            ? names.join(" & ")
            : "${names.take(2).join(", ")} & ${names.length - 2} more";
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final cancelled = order.stage == OrderStage.cancelled;

    return InkWell(
      onTap: () => _OrderDetailsSheet.show(context, order, items),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            _ProductThumb(
              product: items.isEmpty ? null : items.first.product,
              size: 48,
              dimmed: cancelled,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cancelled ? _grey : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                      "${orderDateLabel(order.date)} · $itemCount item${itemCount == 1 ? '' : 's'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 11, color: _grey)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(orderTotal(order)),
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: cancelled ? _grey : Colors.black87,
                        decoration:
                            cancelled ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 4),
                OrderStatusChip(order: order),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Thumbnails
// ─────────────────────────────────────────────
/// Up to four product thumbnails in a row; when there are more items the
/// last slot becomes a "+N" tile.
class _ThumbStrip extends StatelessWidget {
  final List<ResolvedOrderItem> items;

  const _ThumbStrip({required this.items});

  static const _size = 44.0;
  static const _slots = 4;

  @override
  Widget build(BuildContext context) {
    final overflow = items.length > _slots;
    final shown = items.take(overflow ? _slots - 1 : _slots).toList();
    return Row(
      children: [
        for (final item in shown) ...[
          _ProductThumb(product: item.product, size: _size),
          const SizedBox(width: 6),
        ],
        if (overflow)
          Container(
            width: _size,
            height: _size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text("+${items.length - shown.length}",
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _green)),
          ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final ProductModel? product;
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
    final url = product?.imageUrl ?? '';
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty
            ? placeholder
            : Image.network(url,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Order details bottom sheet
// ─────────────────────────────────────────────
class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;
  final List<ResolvedOrderItem> items;

  const _OrderDetailsSheet({required this.order, required this.items});

  static void show(
      BuildContext context, OrderModel order, List<ResolvedOrderItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8),
      builder: (_) => _OrderDetailsSheet(order: order, items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = order.stage;
    final itemsTotal =
        items.fold<double>(0, (sum, i) => sum + i.paidPrice * i.quantity);

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Order #${shortOrderId(order)}",
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                      Text(orderDateLabel(order.date),
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: _grey)),
                    ],
                  ),
                ),
                OrderStatusChip(order: order, fontSize: 11),
              ],
            ),
          ),
          if (stage != OrderStage.cancelled)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _OrderStepper(stage: stage),
            ),
          const Divider(height: 32, color: _border),
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
                    _ProductThumb(product: item.product, size: 48),
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
                              "Qty ${item.quantity} · ${formatPrice(item.paidPrice)} each",
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: _grey)),
                        ],
                      ),
                    ),
                    Text(formatPrice(item.paidPrice * item.quantity),
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
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _billRow("Item total", formatPrice(itemsTotal)),
                const SizedBox(height: 8),
                _billRow("Total paid", formatPrice(orderTotal(order)),
                    bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontFamily: 'Poppins',
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        color: bold ? Colors.black87 : _grey);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

// ─────────────────────────────────────────────
//  Empty, error + loading states
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 44, color: _green),
          ),
          const SizedBox(height: 18),
          const Text("No orders yet",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          const Text(
              "When you place an order, you can track it here until it reaches your door.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  height: 1.4,
                  color: _grey)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 48, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 16),
          const Text("Couldn't load your orders",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: _grey)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Retry",
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height, {double radius = 8}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: const Color(0xFFECEDEF),
              borderRadius: BorderRadius.circular(radius)),
        );

    Widget card({required double height}) => Container(
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                bar(42, 42, radius: 21),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(110, 14), const SizedBox(height: 8), bar(170, 10)],
                ),
              ]),
              const Spacer(),
              Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  bar(44, 44, radius: 10),
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                bar(60, 18),
              ]),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(120, 16),
          const SizedBox(height: 14),
          card(height: 170),
          const SizedBox(height: 24),
          bar(110, 16),
          const SizedBox(height: 14),
          card(height: 120),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// 🔥 1. Import the speech-to-text package
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../blocs/wishlist_bloc/wishlist_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_state.dart';
import '../../../data/repositories/recent_searches_repository.dart';
import '../../../shared/models/category_model.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/utils/product_search.dart';
import '../../../shared/widgets/product_grid.dart';
import '../../../shared/widgets/product_row.dart';
import '../../../shared/widgets/section_header.dart';
import '../../home/blocs/home_bloc.dart';
import '../../product_details/views/product_details_screen.dart';
import '../blocs/search_bloc.dart';
import 'widgets/search_result_tile.dart';

const _green = Color(0xFF3DAA5C);
const _muted = Color(0xFF6B6B6B);
const _border = Color(0xFFE0E0E0);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Owned directly by this State rather than looked up via Provider —
  // dispatching from onChanged/onPressed closures needs a context that's a
  // *descendant* of BlocProvider, but those closures capture build()'s own
  // context, which sits above it. Owning the instance sidesteps that.
  final SearchBloc _searchBloc = SearchBloc(ProductSearchIndex.empty);

  // Built from Home's already-loaded catalog, so searching never hits the
  // network. Rebuilt only when Home hands us a different product/category
  // list (e.g. after a pull-to-refresh/retry).
  ProductSearchIndex _index = ProductSearchIndex.empty;
  List<ProductModel>? _indexedProducts;
  List<CategoryModel>? _indexedCategories;
  Map<String, String> _categoryNames = const {};

  late final RecentSearchesRepository _recentRepo =
      context.read<RecentSearchesRepository>();
  List<String> _recentSearches = const [];

  // 🔥 2. Create the SpeechToText instance
  late stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech(); // Initialize the microphone

    _syncIndex(context.read<HomeBloc>().state);
    _recentRepo.load().then((terms) {
      if (mounted) setState(() => _recentSearches = terms);
    });

    // Repaint the search bar's border when focus changes.
    _searchFocusNode.addListener(() => setState(() {}));

    // Auto-focus keyboard
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  // 🔥 3. Initialize Speech to Text
  void _initSpeech() async {
    _isSpeechAvailable = await _speech.initialize(
      onError: (val) => debugPrint('Speech Error: $val'),
      onStatus: (val) => debugPrint('Speech Status: $val'),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _speech.stop(); // Clean up the mic
    _searchBloc.close();
    super.dispose();
  }

  void _syncIndex(HomeState state) {
    if (state is! HomeLoaded) return;
    if (identical(state.allProducts, _indexedProducts) &&
        identical(state.allCategories, _indexedCategories)) {
      return;
    }
    _indexedProducts = state.allProducts;
    _indexedCategories = state.allCategories;
    _categoryNames = {for (final c in state.allCategories) c.id: c.name};
    _index = ProductSearchIndex.build(state.allProducts, state.allCategories);
    _searchBloc.add(SearchIndexUpdated(_index));
  }

  // Fills the bar with [term] and runs it, e.g. from a recent-search chip.
  void _applyQuery(String term) {
    setState(() {
      _searchController.text = term;
      _searchController.selection =
          TextSelection.collapsed(offset: term.length);
    });
    _searchBloc.add(SearchQueryChanged(term));
  }

  Future<void> _saveRecent(String term) async {
    if (term.trim().isEmpty) return;
    final updated = await _recentRepo.add(term);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _removeRecent(String term) async {
    final updated = await _recentRepo.remove(term);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecent() async {
    final updated = await _recentRepo.clear();
    if (mounted) setState(() => _recentSearches = updated);
  }

  // 🔥 4. The Voice Search Bottom Sheet Logic
  void _startVoiceSearch() async {
    if (!_isSpeechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Speech recognition is not available on this device.")),
      );
      return;
    }

    // Hide the keyboard
    _searchFocusNode.unfocus();

    // Show the "Listening" Bottom Sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      builder: (context) {
        return Container(
          height: 250,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Listening...",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                "Speak what you want to search",
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14, color: _muted),
              ),
              const SizedBox(height: 32),
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _green, width: 2),
                ),
                child: const Icon(Icons.mic_rounded, size: 40, color: _green),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Stop listening when the bottom sheet is closed
      _speech.stop();
      // Bring keyboard back if they want to type
      if (mounted) _searchFocusNode.requestFocus();
    });

    // Start listening and pushing words to the text field!
    await _speech.listen(
      onResult: (result) {
        _applyQuery(result.recognizedWords);

        // If the user stops speaking (result is final), close the bottom sheet
        if (result.finalResult) {
          _saveRecent(result.recognizedWords);
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: BlocListener<HomeBloc, HomeState>(
          listener: (context, state) => _syncIndex(state),
          child: Column(
            children: [
              _buildSearchBar(),
              const Divider(height: 1, thickness: 1, color: _border),
              Expanded(
                child: BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) {
                    if (state is HomeError) return _buildHomeError(state);
                    if (state is! HomeLoaded) {
                      return const Center(
                          child: CircularProgressIndicator(color: _green));
                    }
                    return _searchController.text.trim().isEmpty
                        ? _buildDiscovery(state)
                        : _buildResults();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. ACTIVE SEARCH BAR HEADER ---
  Widget _buildSearchBar() {
    final focused = _searchFocusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 48,
              decoration: BoxDecoration(
                color: focused ? Colors.white : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused ? _green : _border,
                  width: focused ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                cursorColor: _green,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "Search for products...",
                  hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      color: _muted,
                      fontSize: 15,
                      fontWeight: FontWeight.normal),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: focused ? _green : _muted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: _muted, size: 20),
                          onPressed: () => _applyQuery(''),
                        )
                      : IconButton(
                          icon: Icon(Icons.mic_rounded,
                              color: _isSpeechAvailable ? _green : _muted),
                          onPressed: _startVoiceSearch,
                        ),
                ),
                onChanged: (value) {
                  setState(() {});
                  _searchBloc.add(SearchQueryChanged(value));
                },
                onSubmitted: _saveRecent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. DISCOVERY (empty search bar) ---
  Widget _buildDiscovery(HomeLoaded state) {
    return BlocBuilder<WishlistBloc, WishlistState>(
      builder: (context, wishlistState) {
        final wishlist = wishlistState is WishlistLoaded
            ? wishlistState.wishlistItems
            : const <ProductModel>[];
        final suggestions = suggestProducts(
          allProducts: state.allProducts,
          wishlist: wishlist,
          recentSearches: _recentSearches,
          index: _index,
        );

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: 20, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_recentSearches.isNotEmpty) ...[
                SectionHeader(
                  title: "Recent searches",
                  trailing: "Clear",
                  onTrailingTap: _clearRecent,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final term in _recentSearches)
                        _RecentSearchChip(
                          label: term,
                          onTap: () => _applyQuery(term),
                          onRemove: () => _removeRecent(term),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (wishlist.isNotEmpty) ...[
                const SectionHeader(title: "Your wishlist"),
                const SizedBox(height: 14),
                ProductRow(products: wishlist),
                const SizedBox(height: 24),
              ],
              if (suggestions.isNotEmpty) ...[
                const SectionHeader(title: "Suggested for you"),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ProductGrid(
                    products: suggestions,
                    crossAxisCount: 3,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- 3. LIVE SEARCH RESULTS ---
  Widget _buildResults() {
    return BlocBuilder<SearchBloc, SearchState>(
      bloc: _searchBloc,
      builder: (context, searchState) {
        // Briefly SearchInitial while the first debounce is pending.
        if (searchState is! SearchLoaded) return const SizedBox();

        if (searchState.results.isEmpty) {
          return _buildNoResults(searchState.query);
        }

        final count = searchState.results.length;
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          itemCount: count + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 2),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: "$count ${count == 1 ? 'result' : 'results'}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    TextSpan(text: " for '${searchState.query}'"),
                  ]),
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, color: _muted),
                ),
              );
            }

            final product = searchState.results[index - 1];
            return SearchResultTile(
              product: product,
              query: searchState.query,
              categoryName: _categoryNames[product.categoryId],
              onTap: () {
                _saveRecent(searchState.query);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsScreen(product: product),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.search_off_rounded, size: 40, color: _green),
            ),
            const SizedBox(height: 20),
            Text(
              "No results for '$query'",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              "Try a different spelling or a broader term",
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontFamily: 'Poppins', color: _muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeError(HomeError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _muted),
            const SizedBox(height: 16),
            Text(
              "Couldn't load products\n${state.message}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, color: _muted),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.read<HomeBloc>().add(LoadHomeData()),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _green, width: 1),
                ),
              ),
              child: const Text(
                "Retry",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: _green,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentSearchChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, size: 16, color: _muted),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333)),
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child:
                      Icon(Icons.close_rounded, size: 14, color: Color(0xFF9E9E9E)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

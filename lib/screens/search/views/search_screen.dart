import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/mock_data.dart'; // For "Popular Products" fallback
import '../../home/views/widgets/popular_products.dart';
import '../blocs/search_bloc.dart'; // Import the new Bloc
import 'widgets/search_result_tile.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Provide the Bloc to this screen
    return BlocProvider(
      create: (context) => SearchBloc(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("Search",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  // Trigger BLoC event on typing
                  onChanged: (query) {
                    context.read<SearchBloc>().add(SearchQueryChanged(query));
                  },
                  decoration: InputDecoration(
                    hintText: "Search for fruits, vegetables...",
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        _controller.clear();
                        context.read<SearchBloc>().add(SearchQueryChanged(''));
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 2. BlocBuilder handles the State
              BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  // Loading State
                  if (state is SearchLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Results State
                  if (state is SearchLoaded) {
                    if (state.results.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No products found"),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${state.results.length} result(s) found",
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade600),
                            ),
                            const Text("See more",
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // List of Results
                        ...state.results.map((product) => SearchResultTile(
                              product: product,
                              onTap: () {
                                // Navigate to Details
                              },
                            )),
                      ],
                    );
                  }

                  // Initial or Empty State -> Show Suggestions
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "You might also like",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Fallback to static mock data when not searching
                      PopularProducts(products: mockProducts),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

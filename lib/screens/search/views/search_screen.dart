import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app123/data/repositories/product_repository.dart';
import '../blocs/search_bloc.dart';
import 'widgets/search_result_tile.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Provide SearchBloc
    return BlocProvider(
      create: (context) => SearchBloc(context.read<ProductRepository>()),
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
        title: const Text(
          "Search",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar (Fixed at top)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (query) {
                    context.read<SearchBloc>().add(SearchQueryChanged(query));
                  },
                  decoration: InputDecoration(
                    hintText: "Search for fruits, vegetables...",
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () {
                              _controller.clear();
                              context
                                  .read<SearchBloc>()
                                  .add(SearchQueryChanged(''));
                              setState(() {}); // Rebuild to hide X button
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),

            // 2. Search Results (Expanded List)
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  // A. Loading
                  if (state is SearchLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // B. Results Found
                  if (state is SearchLoaded) {
                    if (state.results.isEmpty) {
                      return const Center(
                        child: Text("No products found",
                            style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: state.results.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        return SearchResultTile(
                          product: state.results[index],
                          onTap: () {
                            // TODO: Navigate to Product Details
                          },
                        );
                      },
                    );
                  }

                  // C. Initial State (User hasn't typed yet)
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("Type to search products",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

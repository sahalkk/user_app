import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// 🔥 1. Import the speech-to-text package
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../home/blocs/home_bloc.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 🔥 2. Create the SpeechToText instance
  late stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech(); // Initialize the microphone

    // Auto-focus keyboard
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  // 🔥 3. Initialize Speech to Text
  void _initSpeech() async {
    _isSpeechAvailable = await _speech.initialize(
      onError: (val) => print('Speech Error: $val'),
      onStatus: (val) => print('Speech Status: $val'),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _speech.stop(); // Clean up the mic
    super.dispose();
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
      builder: (context) {
        return Container(
          height: 250,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Listening...",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Speak what you want to search",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              // Big pulsating mic button
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic, size: 40, color: Colors.green.shade700),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Stop listening when the bottom sheet is closed
      _speech.stop();
      // Bring keyboard back if they want to type
      _searchFocusNode.requestFocus();
    });

    // Start listening and pushing words to the text field!
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _searchController.text = result.recognizedWords;
          // Put the cursor at the end of the text
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        });

        // If the user stops speaking (result is final), close the bottom sheet
        if (result.finalResult) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. ACTIVE SEARCH BAR HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.shade100,
                              blurRadius: 4,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Search for products...",
                          hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.grey),

                          // 🔥 5. Update the Suffix Icon to trigger Voice Search
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.grey, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : IconButton(
                                  icon: Icon(Icons.mic,
                                      color: _isSpeechAvailable
                                          ? Colors.green.shade700
                                          : Colors.grey),
                                  onPressed:
                                      _startVoiceSearch, // Trigger the bottom sheet!
                                ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

            // --- 2. SUGGESTIONS BODY ---
            Expanded(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.green));
                  }

                  if (state is HomeLoaded) {
                    if (_searchController.text.isEmpty) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 100, top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("Recent searches",
                                trailing: "clear"),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildRecentChip(
                                      "Milk", Icons.water_drop_outlined),
                                  _buildRecentChip(
                                      "Bread", Icons.bakery_dining_outlined),
                                  _buildRecentChip("Eggs", Icons.egg_outlined),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSectionHeader("Trending in your city"),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: state.categories.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final categoryName =
                                      state.categories[index]['name'] ?? '';
                                  return Column(
                                    children: [
                                      Container(
                                        height: 60,
                                        width: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F8F4),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                        ),
                                        child: Center(
                                          child: Text(
                                            categoryName.isNotEmpty
                                                ? categoryName[0]
                                                : '',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.green.shade800),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(categoryName,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildSectionHeader("Suggested for you"),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: state.allProducts.take(5).length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  return SizedBox(
                                    width: 145,
                                    child: ProductCard(
                                        product: state.allProducts[index]),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // --- 3. LIVE SEARCH RESULTS ---
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              "Searching for '${_searchController.text}'...",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87)),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildRecentChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ],
      ),
    );
  }
}

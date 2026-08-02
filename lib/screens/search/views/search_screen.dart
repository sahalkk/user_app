import 'package:beeyo_customer/shared/widgets/product_row.dart';
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
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF6B6B6B)),
              ),
              const SizedBox(height: 32),
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF3DAA5C).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF3DAA5C), width: 2),
                ),
                child: const Icon(Icons.mic_rounded,
                    size: 40, color: Color(0xFF3DAA5C)),
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
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. ACTIVE SEARCH BAR HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Search for products...",
                          hintStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFF6B6B6B),
                              fontSize: 15,
                              fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Color(0xFF6B6B6B)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Color(0xFF6B6B6B), size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : IconButton(
                                  icon: Icon(Icons.mic_rounded,
                                      color: _isSpeechAvailable
                                          ? const Color(0xFF3DAA5C)
                                          : const Color(0xFF6B6B6B)),
                                  onPressed: _startVoiceSearch,
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

            const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

            // --- 2. SUGGESTIONS BODY ---
            Expanded(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3DAA5C)));
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
                                          color: const Color(0xFFF0F0F0),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFFE0E0E0)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            categoryName.isNotEmpty
                                                ? categoryName[0]
                                                : '',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF3DAA5C)),
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
                            ProductRow(
                              products: state.allProducts.take(5).toList(),
                              itemWidth: 145,
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
                            const Icon(Icons.search_rounded,
                                size: 64, color: Color(0xFFE0E0E0)),
                            const SizedBox(height: 16),
                            Text(
                              "Searching for '${_searchController.text}'...",
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF6B6B6B),
                                  fontSize: 15,
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
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3DAA5C))),
        ],
      ),
    );
  }

  Widget _buildRecentChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF6B6B6B)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333))),
        ],
      ),
    );
  }
}

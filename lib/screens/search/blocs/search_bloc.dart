import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart'; // Optional: for debounce if you have it
import '../../../../data/repositories/product_repository.dart'; // Import Repo
import '../../../../shared/models/product_model.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  // 1. Inject the Repository
  final ProductRepository productRepository;

  SearchBloc(this.productRepository) : super(SearchInitial()) {
    // 2. Add debounce (wait 300ms after typing stops) to prevent API spam
    on<SearchQueryChanged>(_onQueryChanged, transformer: (events, mapper) {
      return events
          .debounceTime(const Duration(milliseconds: 300))
          .asyncExpand(mapper);
    });
  }

  Future<void> _onQueryChanged(
      SearchQueryChanged event, Emitter<SearchState> emit) async {
    if (event.query.isEmpty) {
      emit(SearchInitial()); // Or SearchEmpty
      return;
    }

    emit(SearchLoading());

    try {
      // 3. Call the Real API via Repository
      final results = await productRepository.searchProducts(event.query);
      emit(SearchLoaded(results, event.query));
    } catch (e) {
      print("Search Error: $e");
      // Fallback to empty or error state
      emit(SearchLoaded(const [], event.query));
    }
  }
}

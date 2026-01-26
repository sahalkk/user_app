import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/mock_data.dart';
import '../../../../shared/models/product_model.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchInitial()) {
    on<SearchQueryChanged>(_onQueryChanged);
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    // Debug Print: Check your console to see if this appears when you type!
    print("Bloc received query: ${event.query}");

    if (event.query.isEmpty) {
      emit(SearchEmpty());
      return;
    }

    emit(SearchLoading());

    // LOGIC: Filter the mockProducts list
    try {
      final results = mockProducts
          .where((product) =>
              product.title.toLowerCase().contains(event.query.toLowerCase()))
          .toList();

      emit(SearchLoaded(results, event.query));
    } catch (e) {
      print("Error during search: $e");
    }
  }
}

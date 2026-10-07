import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/utils/product_search.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  ProductSearchIndex _index;
  String _query = '';

  SearchBloc(this._index) : super(SearchInitial()) {
    // Searching is in-memory, so the debounce only saves rebuilds while the
    // user is mid-word. switchMap drops a pending query as soon as a newer
    // one arrives, so stale results can never land after fresh ones.
    on<SearchQueryChanged>(_onQueryChanged, transformer: (events, mapper) {
      return events
          .debounceTime(const Duration(milliseconds: 150))
          .switchMap(mapper);
    });
    on<SearchIndexUpdated>(_onIndexUpdated);
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    _query = event.query;
    _emitResults(emit);
  }

  // Home reloaded the catalog — re-run the current query against it.
  void _onIndexUpdated(SearchIndexUpdated event, Emitter<SearchState> emit) {
    _index = event.index;
    _emitResults(emit);
  }

  void _emitResults(Emitter<SearchState> emit) {
    if (_query.trim().isEmpty) {
      emit(SearchInitial());
      return;
    }
    emit(SearchLoaded(_index.search(_query), _query.trim()));
  }
}

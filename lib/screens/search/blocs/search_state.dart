part of 'search_bloc.dart';

abstract class SearchState {}

// Nothing typed yet (or the bar was cleared).
class SearchInitial extends SearchState {}

class SearchLoaded extends SearchState {
  final List<ProductModel> results;
  final String query; // Useful to show "No results for 'xyz'"

  SearchLoaded(this.results, this.query);
}

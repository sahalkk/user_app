part of 'search_bloc.dart';


abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final List<ProductModel> results;
  final String query; // Useful to show "No results for 'xyz'"

  SearchLoaded(this.results, this.query);
}

class SearchEmpty extends SearchState {
  // Used when search bar is cleared
}

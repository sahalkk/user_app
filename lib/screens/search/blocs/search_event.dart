part of 'search_bloc.dart';

abstract class SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  final String query;
  SearchQueryChanged(this.query);
}

class SearchIndexUpdated extends SearchEvent {
  final ProductSearchIndex index;
  SearchIndexUpdated(this.index);
}

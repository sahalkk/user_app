part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object> get props => [];
}

class LoadHomeData extends HomeEvent {}

// --- NEW EVENT ---
// Triggered when the user taps a category pill/button
class SelectCategory extends HomeEvent {
  final String category;

  const SelectCategory(this.category);

  @override
  List<Object> get props => [category];
}

// Triggered when the user taps an item in the subcategory sidebar
// (null == the sidebar's own "All" entry).
class SelectSubcategory extends HomeEvent {
  final String? subcategoryId;

  const SelectSubcategory(this.subcategoryId);

  @override
  List<Object> get props =>
      subcategoryId == null ? [] : [subcategoryId as Object];
}

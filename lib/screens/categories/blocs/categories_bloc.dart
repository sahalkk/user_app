import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Make sure these paths match where your repository and model are located!
import '../../../../data/repositories/category_repository.dart';
import '../../../../shared/models/category_model.dart';

// This links the other two files to this main file
part 'categories_event.dart';
part 'categories_state.dart';

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final CategoryRepository repository;

  CategoriesBloc(this.repository) : super(CategoriesInitial()) {
    on<LoadCategories>(_onLoadCategories);
  }

  void _onLoadCategories(
      LoadCategories event, Emitter<CategoriesState> emit) async {
    emit(CategoriesLoading());
    try {
      final categories = await repository.getCategories();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }
}

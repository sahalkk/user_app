import '../shared/models/product_model.dart';

List<ProductModel> mockProducts = [
  const ProductModel(
    id: 'mock-1',
    title: "Organic Bananas",
    description: "Fresh organic bananas from local farms.",
    price: "4.99", // NOW A STRING (matches API)
    imageUrl: "https://via.placeholder.com/150?text=Bananas",
    unit: "kg",
  ),
  const ProductModel(
    id: 'mock-2',
    title: "Red Apples",
    description: "Crisp and sweet red apples.",
    price: "3.50",
    imageUrl: "https://via.placeholder.com/150?text=Apples",
    unit: "kg",
  ),
  const ProductModel(
    id: 'mock-3',
    title: "Fresh Broccoli",
    description: "Nutritious green broccoli.",
    price: "2.20",
    imageUrl: "https://via.placeholder.com/150?text=Broccoli",
    unit: "pcs",
  ),
  const ProductModel(
    id: 'mock-4',
    title: "Carrots",
    description: "Crunchy orange carrots.",
    price: "1.99",
    imageUrl: "https://via.placeholder.com/150?text=Carrots",
    unit: "kg",
  ),
  const ProductModel(
    id: 'mock-5',
    title: "Strawberries",
    description: "Sweet and juicy strawberries.",
    price: "5.49",
    imageUrl: "https://via.placeholder.com/150?text=Strawberries",
    unit: "box",
  ),
];

class OrderModel {
  final String id;
  final String orderCode;
  final String productName;
  final int quantity;
  final double totalPrice;
  final double originalPrice;
  final String image;
  final String status; // 'active', 'completed', 'cancelled'
  final String? timerText;
  final double rating;

  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    this.originalPrice = 0,
    required this.image,
    required this.status,
    this.timerText,
    this.rating = 5.0,
  });
}

class OrderData {
  static final List<OrderModel> mockOrders = [
    const OrderModel(
      id: 'ord-001',
      orderCode: '#KK-2026-089',
      productName: 'Lumpia Diego',
      quantity: 1,
      totalPrice: 129.99,
      originalPrice: 129.99,
      image: 'assets/images/lumpia_diego.png',
      status: 'active',
      timerText: '04:12',
    ),
    const OrderModel(
      id: 'ord-002',
      orderCode: 'SP 0023900',
      productName: 'Lumpia Diego',
      quantity: 1,
      totalPrice: 25.20,
      originalPrice: 129.99,
      image: 'assets/images/lumpia_diego.png',
      status: 'active',
      rating: 5.0,
    ),
    const OrderModel(
      id: 'ord-003',
      orderCode: 'SP 0023512',
      productName: 'Paket Hemat Campur',
      quantity: 2,
      totalPrice: 40.00,
      originalPrice: 188.00,
      image: 'assets/images/nasi_kuning.png',
      status: 'completed',
      rating: 5.0,
    ),
    const OrderModel(
      id: 'ord-004',
      orderCode: '#KK-2026-054',
      productName: 'Nasi Kuning Slamet',
      quantity: 2,
      totalPrice: 188.00,
      originalPrice: 188.00,
      image: 'assets/images/nasi_kuning.png',
      status: 'completed',
    ),
    const OrderModel(
      id: 'ord-005',
      orderCode: '#KK-2026-041',
      productName: 'Donat Surgawi',
      quantity: 1,
      totalPrice: 109.00,
      originalPrice: 109.00,
      image: 'assets/images/donat_surgawi.png',
      status: 'completed',
    ),
    const OrderModel(
      id: 'ord-006',
      orderCode: '#KK-2026-032',
      productName: 'Martabak Pecenongan',
      quantity: 1,
      totalPrice: 79.00,
      originalPrice: 79.00,
      image: 'assets/images/martabak.png',
      status: 'completed',
    ),
  ];
}

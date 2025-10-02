import '../models.dart';
import 'malls.dart';

class ProductHit {
  final Product product;
  final Mall mall;
  final Store store;
  const ProductHit(this.product, this.mall, this.store);
}

// Lightweight demo catalog to power the Ideas tab search.
// Prices and availability are illustrative only.
final List<Product> demoProducts = [
  // Sandton City (sandton)
  Product(
    id: 'sandton-ww-butter-500g',
    name: 'Butter 500g',
    mallId: 'sandton',
    storeNodeId: 'S_WW',
    storeName: 'Woolworths',
    tags: ['dairy', 'butter', 'unsalted'],
    priceZar: 49.99,
  ),
  Product(
    id: 'sandton-zara-black-dress',
    name: 'Black Dress',
    mallId: 'sandton',
    storeNodeId: 'S_ZARA',
    storeName: 'ZARA',
    tags: ['dress', 'black', 'fashion', 'women'],
    priceZar: 899.00,
  ),
  Product(
    id: 'sandton-ist-airpods',
    name: 'AirPods (3rd Gen)',
    mallId: 'sandton',
    storeNodeId: 'S_IST',
    storeName: 'iStore',
    tags: ['electronics', 'audio', 'apple'],
    priceZar: 2999.00,
  ),

  // Mall of Africa (moa)
  Product(
    id: 'moa-chk-butter-500g',
    name: 'Butter 500g',
    mallId: 'moa',
    storeNodeId: 'S_CHK',
    storeName: 'Checkers Hyper',
    tags: ['dairy', 'butter'],
    priceZar: 39.99,
  ),
  Product(
    id: 'moa-ww-black-dress',
    name: 'Black Dress',
    mallId: 'moa',
    storeNodeId: 'S_WW',
    storeName: 'Woolworths',
    tags: ['dress', 'black', 'fashion'],
    priceZar: 999.00,
  ),

  // Eastgate (eastgate)
  Product(
    id: 'eastgate-pnp-butter-500g',
    name: 'Butter 500g',
    mallId: 'eastgate',
    storeNodeId: 'S_PNP',
    storeName: 'Pick n Pay',
    tags: ['dairy', 'butter'],
    priceZar: 44.99,
  ),
  Product(
    id: 'eastgate-zara-black-dress',
    name: 'Black Dress',
    mallId: 'eastgate',
    storeNodeId: 'S_ZARA',
    storeName: 'ZARA',
    tags: ['dress', 'black', 'fashion'],
    priceZar: 799.00,
  ),

  // Cresta (cresta)
  Product(
    id: 'cresta-hm-black-dress',
    name: 'Black Dress',
    mallId: 'cresta',
    storeNodeId: 'S_HM',
    storeName: 'H&M',
    tags: ['dress', 'black', 'fashion'],
    priceZar: 549.00,
  ),
];

List<ProductHit> searchProducts(String query, List<Mall> malls) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final tokens = q.split(RegExp(r"\s+"));

  Mall? mallById(String id) => malls.firstWhere((m) => m.id == id, orElse: () => sandtonCity());
  bool matches(Product p) {
    final hay = (p.name + ' ' + p.tags.join(' ')).toLowerCase();
    for (final t in tokens) {
      if (!hay.contains(t)) return false;
    }
    return true;
  }

  final hits = <ProductHit>[];
  for (final p in demoProducts) {
    if (!matches(p)) continue;
    final mall = malls.firstWhere((m) => m.id == p.mallId, orElse: () => sandtonCity());
    final store = mall.stores.firstWhere(
      (s) => s.nodeId == p.storeNodeId,
      orElse: () => const Store(name: 'Unknown', nodeId: ''),
    );
    if (store.nodeId.isEmpty) continue;
    hits.add(ProductHit(p, mall, store));
  }
  // Sort by price ascending by default
  hits.sort((a, b) => a.product.priceZar.compareTo(b.product.priceZar));
  return hits;
}


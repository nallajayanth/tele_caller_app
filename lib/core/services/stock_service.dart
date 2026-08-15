import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StockService {
  static Future<void> adjustStockForNewOrder(String productJson) async {
    if (productJson.isEmpty) return;
    try {
      final items = _parseProducts(productJson);
      if (items.isEmpty) return;

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final item in items) {
        final name = item['name'] as String?;
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        if (name == null || qty <= 0) continue;

        // Find product by name (name is unique/used in the app)
        final snap = await db.collection('products').where('name', isEqualTo: name).limit(1).get();
        if (snap.docs.isNotEmpty) {
          batch.update(snap.docs.first.reference, {'stock': FieldValue.increment(-qty)});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('adjustStockForNewOrder error: $e');
    }
  }

  static Future<void> adjustStockForOrderUpdate(String oldProductJson, String newProductJson) async {
    try {
      final oldItems = _parseProducts(oldProductJson);
      final newItems = _parseProducts(newProductJson);

      // delta = newQty - oldQty
      final Map<String, int> productDeltas = {};

      for (final item in oldItems) {
        final name = item['name'] as String?;
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        if (name == null) continue;
        productDeltas[name] = (productDeltas[name] ?? 0) - qty;
      }

      for (final item in newItems) {
        final name = item['name'] as String?;
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        if (name == null) continue;
        productDeltas[name] = (productDeltas[name] ?? 0) + qty;
      }

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final entry in productDeltas.entries) {
        final name = entry.key;
        final delta = entry.value;
        if (delta == 0) continue;

        final snap = await db.collection('products').where('name', isEqualTo: name).limit(1).get();
        if (snap.docs.isNotEmpty) {
          batch.update(snap.docs.first.reference, {'stock': FieldValue.increment(-delta)});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('adjustStockForOrderUpdate error: $e');
    }
  }

  static Future<void> adjustStockForOrderDeletion(String productJson) async {
    if (productJson.isEmpty) return;
    try {
      final items = _parseProducts(productJson);
      if (items.isEmpty) return;

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final item in items) {
        final name = item['name'] as String?;
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        if (name == null || qty <= 0) continue;

        final snap = await db.collection('products').where('name', isEqualTo: name).limit(1).get();
        if (snap.docs.isNotEmpty) {
          batch.update(snap.docs.first.reference, {'stock': FieldValue.increment(qty)});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('adjustStockForOrderDeletion error: $e');
    }
  }

  static List<Map<String, dynamic>> _parseProducts(String json) {
    if (json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }
}

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/warehouse_api.dart';
import 'package:traceability_app/models/get_warehouse_by_kth_id.dart' as wh;
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class EditWarehouseController extends GetxController {
  final wh.Datum? item;

  EditWarehouseController({this.item});

  final _api = WarehouseApi();

  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final isSaving = false.obs;

  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    WarehouseApi.startAutoSyncListener();

    nameCtrl.text = item?.warehouseName ?? '';
    addressCtrl.text = item?.address ?? '';

    _bootConnectivity();

    _connSub =
        Connectivity().onConnectivityChanged.listen((dynamic conn) {
      isOfflineView.value = !_isOnlineFrom(conn);
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    nameCtrl.dispose();
    addressCtrl.dispose();
    super.onClose();
  }

  Future<void> _bootConnectivity() async {
    final conn = await Connectivity().checkConnectivity();
    isOfflineView.value = !_isOnlineFrom(conn);
  }

  bool _isOnlineFrom(dynamic conn) {
    try {
      final list = (conn as Iterable).cast<ConnectivityResult>();
      if (list.isEmpty) return false;
      return list.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return conn != ConnectivityResult.none;
    }
  }

  Future<void> save(BuildContext context) async {
    final isID = language.value == 'id';

    if (item?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isID
            ? 'Warehouse ID tidak ditemukan'
            : 'Warehouse ID not found'),
      ));
      return;
    }

    if (!formKey.currentState!.validate()) return;

    final name = nameCtrl.text.trim();
    final address = addressCtrl.text.trim();

    int? kthId = item?.kthId;
    if (kthId == null || kthId == 0) {
      final prefs = await SharedPreferences.getInstance();
      kthId = prefs.getInt('kth_id') ?? prefs.getInt('kthId');
    }

    if (kthId == null || kthId == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isID ? 'KTH ID tidak ditemukan' : 'KTH ID not found'),
        ));
      }
      return;
    }

    isSaving.value = true;
    try {
      final res = await _api.editWarehouseOfflineFirst(
        id: item!.id!,
        warehouseName: name,
        address: address,
        kthId: kthId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(res.message))));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      isSaving.value = false;
    }
  }
}

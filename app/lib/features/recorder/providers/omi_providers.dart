import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/recorder/models/omi_device.dart';
import 'package:app/features/recorder/services/omi/models.dart';
import 'package:app/features/recorder/services/omi/omi_bluetooth_service.dart';
import 'package:app/features/recorder/services/omi/omi_capture_service.dart';
import 'package:app/features/recorder/services/omi/omi_firmware_service.dart';
import 'package:app/features/recorder/providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for OmiBluetoothService
///
/// This service manages BLE scanning, device discovery, and connections.
/// It is started automatically when first accessed and kept alive for the app lifetime.
final omiBluetoothServiceProvider = Provider<OmiBluetoothService>((ref) {
  final service = OmiBluetoothService();

  // Start service on creation
  service.start();

  // Clean up on dispose
  ref.onDispose(() async {
    await service.stop();
  });

  return service;
});

/// Provider for the current connection state
///
/// Returns the connection state of the active Omi device connection.
/// This is a StreamProvider that reactively updates when connection state changes.
final omiConnectionStateProvider = StreamProvider<DeviceConnectionState?>((
  ref,
) {
  final bluetoothService = ref.watch(omiBluetoothServiceProvider);
  return bluetoothService.connectionStateStream;
});

/// Provider for the battery level of the connected Omi device
///
/// Returns the battery percentage (0-100) or -1 if unknown.
/// This is a StreamProvider that reactively updates when battery level changes.
final omiBatteryLevelProvider = StreamProvider<int>((ref) {
  final bluetoothService = ref.watch(omiBluetoothServiceProvider);
  return bluetoothService.batteryLevelStream;
});

/// Provider for the currently connected Omi device
///
/// Returns null if no device is connected.
/// This is a StreamProvider that reactively updates when connection state changes.
final connectedOmiDeviceProvider = StreamProvider<OmiDevice?>((ref) {
  final bluetoothService = ref.watch(omiBluetoothServiceProvider);

  // Start with current connection state, then listen to stream
  return bluetoothService.connectedDeviceStream;
});

/// Provider for OmiCaptureService
///
/// This service handles audio recording from the Omi device.
/// It depends on OmiBluetoothService, StorageService, and Whisper services.
///
/// This provider automatically sets up a callback to trigger recordings list refresh
/// when new recordings are saved from the Omi device.
final omiCaptureServiceProvider = Provider<OmiCaptureService>((ref) {
  final bluetoothService = ref.watch(omiBluetoothServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final whisperService = ref.watch(whisperServiceProvider);
  final whisperLocalService = ref.watch(whisperLocalServiceProvider);

  final service = OmiCaptureService(
    bluetoothService: bluetoothService,
    storageService: storageService,
    whisperService: whisperService,
    whisperLocalService: whisperLocalService,
  );

  // Set up callback to trigger recordings list refresh when new recordings are saved
  // This lives for the lifetime of the app, so it won't get disposed like screen callbacks
  service.onRecordingSaved = (recording) {
    // Increment the refresh trigger to notify HomeScreen and other listeners
    ref.read(recordingsRefreshTriggerProvider.notifier).state++;
  };

  // Clean up on dispose
  ref.onDispose(() async {
    await service.dispose();
  });

  return service;
});

/// Provider for OmiFirmwareService
///
/// This service handles OTA firmware updates for Omi devices.
/// Uses ChangeNotifierProvider to enable reactive UI updates during firmware updates.
final omiFirmwareServiceProvider = ChangeNotifierProvider<OmiFirmwareService>((
  ref,
) {
  return OmiFirmwareService();
});

/// Provider for discovered devices during scan
///
/// This is a StateProvider that gets updated during device scanning.
final discoveredOmiDevicesProvider = StateProvider<List<OmiDevice>>((ref) {
  return [];
});

/// Provider for the last paired device ID
///
/// Persists to SharedPreferences for auto-reconnect functionality.
final lastPairedDeviceIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('omi_last_paired_device_id');
});

/// Provider for the last paired device info
///
/// Returns the full OmiDevice object from SharedPreferences.
final lastPairedDeviceProvider = FutureProvider<OmiDevice?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final deviceJson = prefs.getString('omi_last_paired_device_json');

  if (deviceJson == null || deviceJson.isEmpty) {
    return null;
  }

  try {
    final json = jsonDecode(deviceJson) as Map<String, dynamic>;
    return OmiDevice.fromJson(json);
  } catch (e) {
    return null;
  }
});

/// Helper function to save paired device to SharedPreferences
Future<void> savePairedDevice(OmiDevice device) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('omi_last_paired_device_id', device.id);
  await prefs.setString(
    'omi_last_paired_device_json',
    jsonEncode(device.toJson()),
  );
}

/// Helper function to clear paired device from SharedPreferences
Future<void> clearPairedDevice() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('omi_last_paired_device_id');
  await prefs.remove('omi_last_paired_device_json');
}

/// Provider for auto-reconnect preference
final autoReconnectEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('omi_auto_reconnect_enabled') ?? true; // Default to true
});

/// Helper function to save auto-reconnect preference
Future<void> setAutoReconnectEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('omi_auto_reconnect_enabled', enabled);
}

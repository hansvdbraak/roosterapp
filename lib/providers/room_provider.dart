import 'package:flutter/foundation.dart';
import 'package:rooster_client/rooster_client.dart' as server;
import '../models/room.dart';
import '../services/serverpod_client.dart';

class RoomProvider extends ChangeNotifier {
  List<server.Room> _serverRooms = [];

  /// Alle ruimtes (inclusief overbodig)
  List<Room> get rooms => _serverRooms.map(_serverRoomToLocal).toList();

  /// Alleen boekbare ruimtes
  List<Room> get bookableRooms =>
      _serverRooms.where((r) => r.isBookable).map(_serverRoomToLocal).toList();

  /// Alleen overbodige ruimtes
  List<Room> get obsoleteRooms =>
      _serverRooms.where((r) => !r.isBookable).map(_serverRoomToLocal).toList();

  RoomProvider() {
    loadRooms();
  }

  /// Converteer server Room naar lokale Room
  Room _serverRoomToLocal(server.Room serverRoom) {
    return Room(
      id: serverRoom.id ?? 0,
      name: serverRoom.name,
      description: serverRoom.description,
      imageUrl: serverRoom.imageUrl,
      isObsolete: !serverRoom.isBookable,
    );
  }

  /// Laad ruimtes van server
  Future<void> loadRooms() async {
    try {
      _serverRooms = await serverpodClient.room.getRooms();
      notifyListeners();
    } catch (e) {
      debugPrint('Fout bij laden ruimtes: $e');
    }
  }

  /// Nieuwe ruimte toevoegen (alleen superuser)
  Future<Room> addRoom(String name, String? description, [String? imageUrl]) async {
    if (name.trim().isEmpty) {
      throw Exception('Ruimte naam mag niet leeg zijn');
    }

    try {
      final serverRoom = await serverpodClient.room.createRoom(
        name: name,
        description: description,
        imageUrl: imageUrl,
      );

      await loadRooms();
      return _serverRoomToLocal(serverRoom);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Ruimte overbodig maken (alleen superuser)
  Future<void> setRoomObsolete(int roomId, bool obsolete) async {
    try {
      if (obsolete) {
        await serverpodClient.room.setRoomObsolete(roomId);
      } else {
        await serverpodClient.room.updateRoom(
          roomId: roomId,
          isBookable: true,
        );
      }
      await loadRooms();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Ruimte permanent verwijderen
  Future<void> deleteRoom(int roomId) async {
    try {
      await serverpodClient.room.deleteRoom(roomId);
      await loadRooms();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Room? getRoomById(int id) {
    try {
      final serverRoom = _serverRooms.firstWhere((r) => r.id == id);
      return _serverRoomToLocal(serverRoom);
    } catch (e) {
      return null;
    }
  }

  /// Refresh ruimtes van server
  Future<void> refresh() async {
    await loadRooms();
  }
}

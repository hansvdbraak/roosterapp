# Implementatieplan: Roosterapp - Ruimte Reserveringssysteem

## Overzicht

Flutter applicatie voor het reserveren van ruimtes in blokken van 30 minuten. Gebruikers kunnen ruimtes boeken, admins kunnen ruimtes beheren.

## Architectuur

**Client-Server architectuur met Serverpod:**
- **Backend (Serverpod)**: REST API, database (PostgreSQL), business logica
- **Client (Flutter)**:
  - **Data Layer**: Serverpod client SDK, API calls
  - **Business Logic**: State management met Provider
  - **Presentation**: Screens en widgets

## Project Structuur

Het project bestaat uit twee delen:
- **roosterapp_server**: Serverpod backend (nieuwe directory)
- **roosterapp_client**: Flutter applicatie (huidige directory)

## Data Models (Serverpod Protocol)

Serverpod genereert automatisch type-safe models voor client en server. Models worden gedefinieerd in `roosterapp_server/lib/src/protocol/`.

### Benodigde protocol bestanden:

**roosterapp_server/lib/src/protocol/room.yaml**
```yaml
class: Room
table: rooms
fields:
  id: int?, database(index)
  name: String
  description: String?
  createdAt: DateTime, database(default=now)
indexes:
  rooms_name_idx:
    fields: name
    unique: true
```

**roosterapp_server/lib/src/protocol/reservation.yaml**
```yaml
class: Reservation
table: reservations
fields:
  id: int?, database(index)
  roomId: int
  bookerName: String
  date: DateTime
  slotIndex: int  # 0-27 (8:00-22:00, blokken van 30 min)
  createdAt: DateTime, database(default=now)
indexes:
  reservation_unique_slot_idx:
    fields: roomId, date, slotIndex
    unique: true  # Voorkomt dubbele boekingen
```

**roosterapp_server/lib/src/protocol/user_session.yaml**
```yaml
class: UserSession
fields:
  userName: String
  isAdmin: bool
  token: String  # Voor authenticatie
```

**lib/models/time_slot.dart** (Client-only helper class)
```dart
class TimeSlot {
  DateTime date;
  int slotIndex;          // 0-27
  DateTime startTime;     // Berekend
  DateTime endTime;       // startTime + 30 min

  String getDisplayTime() // "08:00 - 08:30"
}
```

Serverpod genereert automatisch:
- Database migrations
- Server-side models met database queries
- Client-side models (gedeeld met Flutter app)
- Type-safe API endpoints

## Screen Structuur

### 1. WelcomeScreen (lib/screens/welcome_screen.dart)
- Login als gebruiker (naam invoeren)
- Login als admin (PIN code)
- Sessie blijft bewaard

### 2. RoomListScreen (lib/screens/room_list_screen.dart)
- Overzicht van alle ruimtes als cards
- Kleurcodering: groen (beschikbaar), rood (bezet)
- Toon boeker naam bij bezette ruimtes
- FAB voor admin: ruimte toevoegen
- AppBar: huidige gebruiker, datum selectie, logout

### 3. RoomDetailScreen (lib/screens/room_detail_screen.dart)
- Ruimte naam en beschrijving
- Datum navigator (vorige/volgende dag)
- Lijst van 28 tijdslots (8:00-22:00)
- Per slot:
  - Tijdrange tonen
  - Status: beschikbaar/bezet
  - Boeker naam indien bezet
  - Actieknoppen:
    - Beschikbaar → "Boek" knop
    - Eigen reservering → "Annuleer" knop
    - Andere reservering → "Annuleer" (alleen admin)

### 4. AddRoomScreen (lib/screens/add_room_screen.dart) - Admin only
- Formulier voor ruimte naam (verplicht)
- Formulier voor beschrijving (optioneel)
- Opslaan/Annuleren knoppen

## Backend - Serverpod Endpoints

### roosterapp_server/lib/src/endpoints/auth_endpoint.dart
```dart
class AuthEndpoint extends Endpoint {
  // POST /auth/loginUser
  Future<UserSession> loginUser(String userName)

  // POST /auth/loginAdmin
  Future<UserSession?> loginAdmin(String pin)

  // POST /auth/logout
  Future<void> logout()
}
```

### roosterapp_server/lib/src/endpoints/room_endpoint.dart
```dart
class RoomEndpoint extends Endpoint {
  // GET /room/list
  Future<List<Room>> getRooms()

  // POST /room/create (admin only)
  Future<Room> createRoom(String name, String? description)

  // DELETE /room/{id} (admin only)
  Future<void> deleteRoom(int roomId)

  // GET /room/{id}
  Future<Room?> getRoom(int roomId)
}
```

### roosterapp_server/lib/src/endpoints/reservation_endpoint.dart
```dart
class ReservationEndpoint extends Endpoint {
  // GET /reservation/list?roomId={id}&date={date}
  Future<List<Reservation>> getReservations(int roomId, DateTime date)

  // POST /reservation/create
  Future<Reservation> createReservation(int roomId, String bookerName, DateTime date, int slotIndex)

  // DELETE /reservation/{id}
  Future<void> cancelReservation(int reservationId, String userName, bool isAdmin)

  // GET /reservation/slot?roomId={id}&date={date}&slotIndex={index}
  Future<Reservation?> getReservationForSlot(int roomId, DateTime date, int slotIndex)

  // GET /reservation/user/{userName}
  Future<List<Reservation>> getReservationsByUser(String userName)
}
```

## Client - State Management met Provider

### lib/providers/auth_provider.dart
```dart
class AuthProvider extends ChangeNotifier {
  final Client serverpodClient;
  UserSession? _currentSession;
  static const String ADMIN_PIN = "1234";

  // Methods (roepen Serverpod endpoints aan):
  - Future<void> loginAsUser(String userName)
  - Future<bool> loginAsAdmin(String pin)
  - Future<void> logout()
}
```

### lib/providers/room_provider.dart
```dart
class RoomProvider extends ChangeNotifier {
  final Client serverpodClient;
  List<Room> _rooms = [];

  // Methods (roepen Serverpod endpoints aan):
  - Future<void> loadRooms()
  - Future<Room> addRoom(String name, String? description)
  - Future<void> deleteRoom(int roomId)
  - Room? getRoomById(int id)
}
```

### lib/providers/reservation_provider.dart
```dart
class ReservationProvider extends ChangeNotifier {
  final Client serverpodClient;
  List<Reservation> _reservations = [];

  // Methods (roepen Serverpod endpoints aan):
  - Future<void> loadReservations(int roomId, DateTime date)
  - Future<Reservation> createReservation(int roomId, String bookerName, DateTime date, int slotIndex)
  - Future<void> cancelReservation(int reservationId, String userName, bool isAdmin)
  - Future<List<Reservation>> getReservationsForRoom(int roomId, DateTime date)
  - Future<Reservation?> getReservationForSlot(int roomId, DateTime date, int slotIndex)
  - Future<bool> isSlotAvailable(int roomId, DateTime date, int slotIndex)
}
```

## Database - PostgreSQL

Serverpod gebruikt PostgreSQL als database. Het schema wordt automatisch gegenereerd uit de protocol bestanden.

### Database Tabellen:

**rooms**
- id (SERIAL PRIMARY KEY)
- name (VARCHAR UNIQUE)
- description (TEXT NULL)
- createdAt (TIMESTAMP DEFAULT NOW())

**reservations**
- id (SERIAL PRIMARY KEY)
- roomId (INTEGER REFERENCES rooms(id))
- bookerName (VARCHAR)
- date (DATE)
- slotIndex (INTEGER) -- 0-27
- createdAt (TIMESTAMP DEFAULT NOW())
- UNIQUE(roomId, date, slotIndex) -- Voorkomt dubbele boekingen

### Database Setup:

1. Installeer PostgreSQL
2. Maak database aan: `roosterapp_db`
3. Configureer in `roosterapp_server/config/`
4. Run migrations: `serverpod create-migration` en `serverpod migrate`

## Dependencies

### Backend (roosterapp_server/pubspec.yaml)

```yaml
name: roosterapp_server
dependencies:
  serverpod: ^2.0.0          # Serverpod framework
  serverpod_postgres: ^2.0.0 # PostgreSQL support
```

### Client (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

  # State Management
  provider: ^6.1.1

  # Serverpod Client
  serverpod_flutter: ^2.0.0
  roosterapp_client:         # Gegenereerde client code
    path: ../roosterapp_server/roosterapp_client

  # Date/Time Utilities
  intl: ^0.19.0
```

### CLI Dependencies (installeer globaal)

```bash
dart pub global activate serverpod_cli
```

## Implementatie Volgorde

### Fase 0: Serverpod Setup (Dag 1)
1. Installeer PostgreSQL lokaal
2. Installeer Serverpod CLI: `dart pub global activate serverpod_cli`
3. Maak Serverpod project: `serverpod create roosterapp_server`
4. Configureer database connectie in `roosterapp_server/config/development.yaml`
5. Test server: `cd roosterapp_server && dart bin/main.dart`

### Fase 1: Backend - Data Models (Dagen 2-3)
6. Definieer protocol bestanden:
   - `roosterapp_server/lib/src/protocol/room.yaml`
   - `roosterapp_server/lib/src/protocol/reservation.yaml`
   - `roosterapp_server/lib/src/protocol/user_session.yaml`
7. Genereer code: `serverpod generate`
8. Maak migrations: `serverpod create-migration`
9. Run migrations: `serverpod migrate`

### Fase 2: Backend - Endpoints (Dagen 4-5)
10. Implementeer AuthEndpoint:
    - loginUser, loginAdmin, logout
11. Implementeer RoomEndpoint:
    - getRooms, createRoom, deleteRoom, getRoom
12. Implementeer ReservationEndpoint:
    - getReservations, createReservation, cancelReservation
    - getReservationForSlot, getReservationsByUser
13. Voeg validatie toe (admin PIN check, duplicate prevention)
14. Test endpoints met Postman/curl

### Fase 3: Client Setup (Dag 6)
15. Update Flutter pubspec.yaml met Serverpod client dependencies
16. Maak folder structuur in lib/:
    - lib/providers/
    - lib/screens/
    - lib/widgets/
    - lib/utils/
17. Initialiseer Serverpod client in main.dart
18. Setup MultiProvider met serverpodClient dependency injection

### Fase 4: Client - State Management (Dagen 7-8)
19. Implementeer AuthProvider met Serverpod calls
20. Implementeer RoomProvider met Serverpod calls
21. Implementeer ReservationProvider met Serverpod calls
22. Voeg error handling toe (network errors, API errors)

### Fase 5: Client - Authenticatie (Dag 9)
23. Maak WelcomeScreen met login dialogen
24. Implementeer navigatie logica (welcome → room list)
25. Test login flows (user en admin)

### Fase 6: Client - Core Screens (Dagen 10-12)
26. Maak RoomListScreen met room cards
27. Maak AddRoomScreen (admin functionaliteit)
28. Maak RoomDetailScreen met slot weergave
29. Implementeer real-time updates (optional: polling of WebSockets)

### Fase 7: Client - Booking Logica (Dagen 13-14)
30. Implementeer boek/annuleer functionaliteit
31. Voeg validatie en error handling toe
32. Implementeer bevestigingsdialogen
33. Test dubbele boeking preventie

### Fase 8: Polish & Testing (Dagen 15-16)
34. Verbeter UI/UX (loading indicators, animaties)
35. Test alle flows end-to-end
36. Test edge cases en network errors
37. Performance optimalisatie (caching, lazy loading)

## Kritieke Bestanden voor Implementatie

**Prioriteit 1 - Backend (Serverpod):**
- `roosterapp_server/lib/src/protocol/reservation.yaml` - Centrale data model definitie
- `roosterapp_server/lib/src/endpoints/reservation_endpoint.dart` - Booking logica
- `roosterapp_server/lib/src/endpoints/room_endpoint.dart` - Room management
- `roosterapp_server/lib/src/endpoints/auth_endpoint.dart` - Authenticatie
- `roosterapp_server/config/development.yaml` - Database configuratie

**Prioriteit 2 - Client State Management:**
- `lib/main.dart` - Entry point, Serverpod client setup, MultiProvider
- `lib/providers/reservation_provider.dart` - Client-side booking state
- `lib/providers/room_provider.dart` - Client-side room state
- `lib/providers/auth_provider.dart` - Client-side auth state

**Prioriteit 3 - UI:**
- `lib/screens/room_detail_screen.dart` - Primaire interface
- `lib/screens/room_list_screen.dart` - Home screen
- `lib/screens/welcome_screen.dart` - Authenticatie

## Design Beslissingen

**Serverpod als backend framework:**
- Type-safe API calls tussen client en server
- Automatische code generatie (models, endpoints)
- PostgreSQL integratie out-of-the-box
- Real-time updates mogelijk met WebSockets
- Dart op zowel client als server (code reuse)
- Production-ready met auth, caching, logging

**SlotIndex systeem (0-27):**
- Vereenvoudigt tijd berekeningen
- Betrouwbaarder dan DateTime vergelijkingen
- Makkelijk aan te passen voor andere blok groottes
- Database UNIQUE constraint voorkomt dubbele boekingen

**PostgreSQL database:**
- ACID compliance (voorkomt race conditions bij boeken)
- Schaalbaar voor productie gebruik
- UNIQUE index op (roomId, date, slotIndex) voorkomt conflicts
- Makkelijk te migreren naar cloud (AWS RDS, Google Cloud SQL)

**Provider voor state management:**
- Laagdrempelig, officieel aanbevolen
- Perfect voor deze complexiteit
- Minimale boilerplate code
- Goede integratie met async Serverpod calls

**Simpele authenticatie:**
- Gebruikers voeren naam in (geen registratie)
- Admin heeft PIN code (1234) - server-side verificatie
- Sessie token voor API calls
- Kan later upgraden naar OAuth/JWT

## Edge Cases

**Te behandelen (server-side):**
- Voorkom dubbele boeking (UNIQUE constraint + endpoint validatie)
- Voorkom boeken van verleden tijdslots (endpoint validatie)
- Valideer userName niet leeg (endpoint validatie)
- Controleer admin rechten voor delete operations
- Database transaction rollback bij fouten
- Rate limiting voor API calls

**Te behandelen (client-side):**
- Gebruikers kunnen alleen eigen reserveringen annuleren
- Admin kan alle reserveringen annuleren
- Bevestig voor annuleren/boeken
- Handle network errors gracefully (retry, offline message)
- Loading states tijdens API calls
- Optimistic updates met rollback bij failure

## Data Flow Voorbeeld - Ruimte Boeken

1. Gebruiker opent RoomDetailScreen voor "Vergaderzaal A" op 15 jan
2. Screen genereert 28 TimeSlot objecten voor die datum
3. ReservationProvider roept Serverpod endpoint aan:
   - `GET /reservation/list?roomId=1&date=2025-01-15`
   - Server query: `SELECT * FROM reservations WHERE roomId=1 AND date='2025-01-15'`
   - Resultaat: lijst van Reservation objecten
4. Voor elk slot: check of er een reservering bestaat
5. Gebruiker klikt "Boek" voor slot 14:00 (slotIndex 12)
6. Bevestigingsdialoog verschijnt
7. Bij bevestiging: ReservationProvider.createReservation()
   - Optimistic update: toon direct als bezet (UI feedback)
   - API call: `POST /reservation/create` met body:
     ```json
     {
       "roomId": 1,
       "bookerName": "Jan Janssen",
       "date": "2025-01-15",
       "slotIndex": 12
     }
     ```
   - Server validatie:
     - Check of slot nog beschikbaar (UNIQUE constraint)
     - Check of datum niet in verleden
     - Check of userName niet leeg
   - Database INSERT met transaction
   - Server returnt nieuwe Reservation object
   - Client: notifyListeners() → UI update met server data
   - Bij fout: rollback optimistic update, toon error
8. Slot toont nu "Bezet door Jan Janssen"
9. Terug naar RoomListScreen: card toont ruimte bezet (data refresh via API)

## Serverpod Deployment

### Development
```bash
cd roosterapp_server
dart bin/main.dart
```
Server draait op `http://localhost:8080`

### Production
Serverpod ondersteunt deployment naar:
- **Docker**: Container image met PostgreSQL
- **AWS**: EC2 + RDS
- **Google Cloud**: Cloud Run + Cloud SQL
- **Azure**: App Service + PostgreSQL

Configuratie bestanden:
- `roosterapp_server/config/development.yaml` - Lokale ontwikkeling
- `roosterapp_server/config/staging.yaml` - Test omgeving
- `roosterapp_server/config/production.yaml` - Productie

## Toekomstige Uitbreidingen (Post-MVP)

- **Real-time updates**: Serverpod WebSockets voor live reservering updates
- **Authentication upgrade**: JWT tokens, OAuth2, refresh tokens
- **Terugkerende reserveringen**: Wekelijkse/dagelijkse patronen
- **Push notificaties**: Voor aankomende reserveringen (Firebase)
- **Calendar view**: Week/maand overzicht met multi-room display
- **Statistieken**: Room utilization dashboard (admin)
- **Multi-ruimte booking**: Meerdere ruimtes tegelijk boeken
- **Wachtlijst**: Automatisch toewijzen bij annulering
- **Email notificaties**: Bevestiging en herinneringen
- **API rate limiting**: Throttling per gebruiker
- **Audit logging**: Wie heeft wat geboekt/geannuleerd
- **Export functionaliteit**: CSV/PDF export van reserveringen

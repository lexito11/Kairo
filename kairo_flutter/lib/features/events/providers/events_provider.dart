import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../auth/services/auth_service.dart';
import '../constants/events_constants.dart';
import '../data/events_mock_data.dart';
import '../models/event_data.dart';
import '../models/estado_verificacion.dart';
import '../services/churches_repository.dart';
import '../services/events_prefs_service.dart';
import '../services/events_repository.dart';

class EventsProvider extends ChangeNotifier {
  EventsProvider({
    EventsPrefsService? prefs,
    ChurchesRepository? churchesRepository,
    EventsRepository? eventsRepository,
  })  : _prefs = prefs ?? EventsPrefsService(),
        _churchesRepository = churchesRepository ?? ChurchesRepository(),
        _eventsRepository = eventsRepository ?? EventsRepository() {
    _initAttendance();
    _loadDenomination();
  }

  final EventsPrefsService _prefs;
  final ChurchesRepository _churchesRepository;
  final EventsRepository _eventsRepository;
  final List<EventData> allEvents = buildMockEvents();
  final Map<String, AttendanceInfo> attendanceCounts = {};

  String? selectedDenomination;
  bool showInitialSelector = false;
  bool isLoading = true;
  EventFilterType activeFilter = EventFilterType.todos;
  EventScope eventScope = EventScope.cristianos;
  EventData? selectedEvent;
  bool showChurchRegistration = false;
  bool showEventRequestForm = false;
  bool showFilterPanel = false;
  String searchTerm = '';
  List<String> selectedChristianCategories = [];
  List<String> selectedChristianTypes = [];
  bool showLiveSectionInfo = false;
  bool showDenominationDropdown = false;
  ChurchFormData churchFormData = ChurchFormData.empty;
  EventRequestFormData eventRequestForm = EventRequestFormData.empty;
  bool churchSubmitting = false;
  bool eventSubmitting = false;
  String? churchSubmitError;
  String? eventSubmitError;
  bool showChurchReviewNotice = false;
  String reviewNoticeTitle = 'En revisión';
  String reviewNoticeMessage = 'Tu solicitud está siendo evaluada por nuestro equipo.';
  bool reviewNoticeRejected = false;
  ChurchRecord? myChurch;
  String? myChurchStatus;
  bool hasPendingEventRequest = false;

  void _initAttendance() {
    final random = Random();
    for (final event in allEvents) {
      attendanceCounts[event.id] = AttendanceInfo(
        attending: random.nextInt(50) + 10,
        notAttending: random.nextInt(20) + 1,
      );
    }
  }

  Future<void> _loadDenomination() async {
    isLoading = true;
    notifyListeners();

    final userId = AuthService().currentUser?.id;
    if (userId != null) {
      final saved = await _prefs.getDenomination(userId);
      if (saved != null) {
        selectedDenomination = saved;
        showInitialSelector = false;
      } else {
        showInitialSelector = true;
      }
      await _refreshMyChurch();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshMyChurch() async {
    try {
      myChurch = await _churchesRepository.getMyChurch();
      myChurchStatus = myChurch != null
          ? EstadoVerificacion.normalize(myChurch!.estadoVerificacion)
          : EstadoVerificacion.normalize(await _prefs.getChurchStatus());
      if (myChurch != null) {
        await _prefs.setRegisteredChurch(true);
        await _prefs.setChurchStatus(myChurchStatus);
      }
      if (myChurch?.isActive == true) {
        hasPendingEventRequest = await _eventsRepository.hasPendingEventRequest();
      } else {
        hasPendingEventRequest = false;
      }
    } catch (_) {
      myChurchStatus ??= EstadoVerificacion.normalize(await _prefs.getChurchStatus());
    }
  }

  String get displayDenomination =>
      selectedDenomination != null ? (denominationNames[selectedDenomination] ?? selectedDenomination!) : 'Bautista';

  int get liveCount => allEvents.where((e) => e.isLive).length;

  List<EventData> get todayEvents => filterBySearch(allEvents.where((e) => e.isToday).toList());

  List<EventData> get upcomingEvents => filterBySearch(allEvents.where((e) => e.isFuture).toList());

  List<EventData> get filteredEvents => getFilteredEvents();

  List<EventData> filterBySearch(List<EventData> events) {
    if (searchTerm.trim().isEmpty) return events;
    final term = searchTerm.toLowerCase().trim();
    return events.where((event) {
      return event.title.toLowerCase().contains(term) ||
          event.church.toLowerCase().contains(term) ||
          event.location.toLowerCase().contains(term) ||
          event.category.toLowerCase().contains(term) ||
          event.description.toLowerCase().contains(term);
    }).toList();
  }

  List<EventData> getFilteredEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<EventData> events;

    switch (activeFilter) {
      case EventFilterType.hoy:
        events = allEvents.where((event) {
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
          if (eventDate != today) return false;
          if (event.isLive) return true;
          final eventTime = event.time.split('-').first.trim();
          final parts = eventTime.split(':');
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          final eventDateTime = DateTime(event.date.year, event.date.month, event.date.day, hours, minutes);
          return !eventDateTime.isBefore(now);
        }).toList();
      case EventFilterType.enVivo:
        events = allEvents.where((e) => e.isLive).toList();
      case EventFilterType.proximos:
        events = allEvents.where((e) => e.isFuture).toList();
      case EventFilterType.todos:
        events = List<EventData>.from(allEvents);
    }

    if (eventScope == EventScope.cristianos || eventScope == EventScope.iglesia) {
      if (selectedChristianCategories.isNotEmpty) {
        events = events.where((e) => selectedChristianCategories.contains(e.denomination)).toList();
      }
      if (selectedChristianTypes.isNotEmpty) {
        events = events.where((event) {
          final cat = event.category.toLowerCase();
          return selectedChristianTypes.any((type) {
            final t = type.toLowerCase();
            if (t.startsWith('cultos')) return cat.contains('culto');
            if (t.startsWith('estudios')) return cat.contains('estudio');
            if (t.startsWith('conferencias')) return cat.contains('conferencia');
            if (t.startsWith('retiros')) return cat.contains('retiro');
            if (t.startsWith('alabanza')) return cat.contains('alabanza');
            if (t.startsWith('bautismos')) return cat.contains('bautism');
            return false;
          });
        }).toList();
      }
    }

    return filterBySearch(events);
  }

  Future<void> handleDenominationSelect(String denomination) async {
    final userId = AuthService().currentUser?.id;
    if (userId != null) {
      await _prefs.setDenomination(userId, denomination);
    }
    selectedDenomination = denomination;
    showInitialSelector = false;
    notifyListeners();
  }

  void skipInitialSelector() {
    showInitialSelector = false;
    notifyListeners();
  }

  void setActiveFilter(EventFilterType filter) {
    activeFilter = filter;
    notifyListeners();
  }

  void setEventScope(EventScope scope) {
    eventScope = scope;
    notifyListeners();
  }

  void setSearchTerm(String value) {
    searchTerm = value;
    notifyListeners();
  }

  void clearSearch() {
    searchTerm = '';
    notifyListeners();
  }

  void toggleChristianCategory(String name) {
    if (selectedChristianCategories.contains(name)) {
      selectedChristianCategories = selectedChristianCategories.where((c) => c != name).toList();
    } else {
      selectedChristianCategories = [...selectedChristianCategories, name];
    }
    notifyListeners();
  }

  void toggleChristianType(String type) {
    if (selectedChristianTypes.contains(type)) {
      selectedChristianTypes = selectedChristianTypes.where((t) => t != type).toList();
    } else {
      selectedChristianTypes = [...selectedChristianTypes, type];
    }
    notifyListeners();
  }

  void openEvent(EventData event) {
    selectedEvent = event;
    notifyListeners();
  }

  void closeEvent() {
    selectedEvent = null;
    notifyListeners();
  }

  void setShowFilterPanel(bool value) {
    showFilterPanel = value;
    notifyListeners();
  }

  void setShowDenominationDropdown(bool value) {
    showDenominationDropdown = value;
    notifyListeners();
  }

  void setShowLiveSectionInfo(bool value) {
    showLiveSectionInfo = value;
    notifyListeners();
  }

  void _showPendingNotice({
    required String title,
    required String message,
    bool rejected = false,
  }) {
    showChurchRegistration = false;
    showEventRequestForm = false;
    reviewNoticeTitle = title;
    reviewNoticeMessage = message;
    reviewNoticeRejected = rejected;
    showChurchReviewNotice = true;
  }

  Future<void> onCreateEventTap() async {
    await _refreshMyChurch();

    final registeredLocally = await _prefs.hasRegisteredChurch();
    final status = myChurchStatus ?? EstadoVerificacion.normalize(await _prefs.getChurchStatus());

    // Ya tiene iglesia (o quedó registrada localmente): nunca volver a pedir registro.
    if (myChurch != null || registeredLocally) {
      if (myChurch?.isRejected == true || EstadoVerificacion.isRechazado(status)) {
        _showPendingNotice(
          title: 'Solicitud rechazada',
          message: myChurch?.motivoRechazo?.isNotEmpty == true
              ? 'Tu solicitud de iglesia fue rechazada: ${myChurch!.motivoRechazo}'
              : 'Tu solicitud de iglesia fue rechazada. Contacta al soporte si necesitas más información.',
          rejected: true,
        );
      } else if (myChurch?.isPending == true ||
          EstadoVerificacion.isPendiente(status) ||
          myChurch == null) {
        _showPendingNotice(
          title: 'En revisión',
          message:
              'Tu iglesia está siendo evaluada. Cuando sea aprobada podrás solicitar la creación de eventos.',
        );
      } else if (hasPendingEventRequest) {
        _showPendingNotice(
          title: 'Evento en revisión',
          message: 'Ya tienes una solicitud de evento pendiente. Espera la aprobación para publicar otra.',
        );
      } else {
        showChurchRegistration = false;
        showChurchReviewNotice = false;
        showEventRequestForm = true;
        eventSubmitError = null;
      }
      notifyListeners();
      return;
    }

    showChurchRegistration = true;
    showEventRequestForm = false;
    showChurchReviewNotice = false;
    notifyListeners();
  }

  void setShowChurchRegistration(bool value) {
    showChurchRegistration = value;
    notifyListeners();
  }

  void setShowEventRequestForm(bool value) {
    showEventRequestForm = value;
    notifyListeners();
  }

  void updateChurchForm(ChurchFormData data) {
    churchFormData = data;
    churchSubmitError = null;
    notifyListeners();
  }

  void updateEventRequestForm(EventRequestFormData data) {
    eventRequestForm = data;
    eventSubmitError = null;
    notifyListeners();
  }

  Future<void> submitChurchRegistration() async {
    final form = churchFormData;
    final validationError = form.validationError();
    if (validationError != null) {
      churchSubmitError = validationError;
      notifyListeners();
      return;
    }

    churchSubmitting = true;
    churchSubmitError = null;
    showChurchReviewNotice = false;
    notifyListeners();

    try {
      final church = await _churchesRepository.registerChurch(form);
      myChurch = church;
      myChurchStatus = EstadoVerificacion.pendiente;
      await _prefs.setRegisteredChurch(true);
      await _prefs.setChurchStatus(EstadoVerificacion.pendiente);
      showChurchRegistration = false;
      churchFormData = ChurchFormData.empty;
      _showPendingNotice(
        title: 'En revisión',
        message: 'Tu solicitud de iglesia está siendo evaluada por nuestro equipo.',
      );
    } catch (e) {
      churchSubmitError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      churchSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> submitEventRequest() async {
    final form = eventRequestForm;
    final validationError = form.validationError();
    if (validationError != null) {
      eventSubmitError = validationError;
      notifyListeners();
      return;
    }

    eventSubmitting = true;
    eventSubmitError = null;
    notifyListeners();

    try {
      await _eventsRepository.requestEvent(
        form: form,
        churchId: myChurch?.id,
        denomination: selectedDenomination,
      );
      hasPendingEventRequest = true;
      eventRequestForm = EventRequestFormData.empty;
      showEventRequestForm = false;
      _showPendingNotice(
        title: 'Evento en revisión',
        message: 'Tu solicitud de evento fue enviada. Quedará en espera hasta ser aprobada.',
      );
    } catch (e) {
      eventSubmitError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      eventSubmitting = false;
      notifyListeners();
    }
  }

  void clearChurchReviewNotice() {
    showChurchReviewNotice = false;
    notifyListeners();
  }

  void clearChurchSubmitMessage() {
    churchSubmitError = null;
    notifyListeners();
  }

  void handleAttending(String eventId) {
    final current = attendanceCounts[eventId] ?? const AttendanceInfo();
    if (current.userStatus == AttendanceStatus.attending) {
      attendanceCounts[eventId] = current.copyWith(attending: current.attending - 1, clearUserStatus: true);
    } else if (current.userStatus == AttendanceStatus.notAttending) {
      attendanceCounts[eventId] = current.copyWith(
        attending: current.attending + 1,
        notAttending: current.notAttending - 1,
        userStatus: AttendanceStatus.attending,
      );
    } else {
      attendanceCounts[eventId] = current.copyWith(
        attending: current.attending + 1,
        userStatus: AttendanceStatus.attending,
      );
    }
    notifyListeners();
  }

  void handleNotAttending(String eventId) {
    final current = attendanceCounts[eventId] ?? const AttendanceInfo();
    if (current.userStatus == AttendanceStatus.notAttending) {
      attendanceCounts[eventId] = current.copyWith(notAttending: current.notAttending - 1, clearUserStatus: true);
    } else if (current.userStatus == AttendanceStatus.attending) {
      attendanceCounts[eventId] = current.copyWith(
        attending: current.attending - 1,
        notAttending: current.notAttending + 1,
        userStatus: AttendanceStatus.notAttending,
      );
    } else {
      attendanceCounts[eventId] = current.copyWith(
        notAttending: current.notAttending + 1,
        userStatus: AttendanceStatus.notAttending,
      );
    }
    notifyListeners();
  }

  AttendanceInfo attendanceFor(String eventId) => attendanceCounts[eventId] ?? const AttendanceInfo();
}

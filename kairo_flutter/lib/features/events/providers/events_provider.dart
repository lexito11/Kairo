import 'package:flutter/foundation.dart';

import '../../auth/services/auth_service.dart';
import '../constants/events_constants.dart';
import '../models/event_data.dart';
import '../models/estado_verificacion.dart';
import '../services/churches_repository.dart';
import '../services/events_prefs_service.dart';
import '../services/events_repository.dart';

enum EventDateRange { any, today, week, month }

class EventsProvider extends ChangeNotifier {
  EventsProvider({
    EventsPrefsService? prefs,
    ChurchesRepository? churchesRepository,
    EventsRepository? eventsRepository,
  })  : _prefs = prefs ?? EventsPrefsService(),
        _churchesRepository = churchesRepository ?? ChurchesRepository(),
        _eventsRepository = eventsRepository ?? EventsRepository() {
    _bootstrap();
  }

  final EventsPrefsService _prefs;
  final ChurchesRepository _churchesRepository;
  final EventsRepository _eventsRepository;
  List<EventData> allEvents = [];

  String? selectedDenomination;
  bool showInitialSelector = false;
  bool isLoading = true;
  bool eventsLoading = false;
  String? eventsError;
  EventFilterType activeFilter = EventFilterType.todos;
  EventScope eventScope = EventScope.cristianos;
  EventDateRange dateRange = EventDateRange.any;
  EventData? selectedEvent;
  bool showChurchRegistration = false;
  bool showEventRequestForm = false;
  bool showFilterPanel = false;
  String searchTerm = '';
  List<String> selectedChristianCategories = [];
  List<String> selectedChristianTypes = [];
  bool showLiveSectionInfo = false;
  bool showDenominationDropdown = false;
  bool showDenominationChangeForm = false;
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

  Future<void> _bootstrap() async {
    isLoading = true;
    notifyListeners();

    final userId = AuthService().currentUser?.id;
    final saved = await _prefs.getDenomination(userId);
    if (saved != null && saved.isNotEmpty) {
      selectedDenomination = saved;
      showInitialSelector = false;
      if (userId != null) {
        await _prefs.setDenomination(userId, saved);
      }
    } else {
      showInitialSelector = userId != null;
    }
    if (userId != null) {
      await _refreshMyChurch();
    }

    isLoading = false;
    notifyListeners();
    await refreshEvents();
  }

  Future<void> refreshEvents() async {
    eventsLoading = allEvents.isEmpty;
    eventsError = null;
    notifyListeners();
    try {
      final denomination = eventScope == EventScope.iglesia ? selectedDenomination : null;
      final items = await _eventsRepository.fetchUpcoming(denomination: denomination);
      allEvents = items.map(EventData.fromItem).toList();
    } catch (e) {
      eventsError = _eventsRepository.mapError(e);
    } finally {
      eventsLoading = false;
      notifyListeners();
    }
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

  bool _matchesDenominationFilter(EventData event, String filterName) {
    final label = event.denomination.toLowerCase();
    final key = denominationNames.entries
        .firstWhere(
          (e) => e.value.toLowerCase() == filterName.toLowerCase() || e.key == filterName.toLowerCase(),
          orElse: () => MapEntry(filterName.toLowerCase(), filterName),
        )
        .key;
    return label == filterName.toLowerCase() || label == key;
  }

  bool _inDateRange(EventData event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
    switch (dateRange) {
      case EventDateRange.any:
        return true;
      case EventDateRange.today:
        return eventDay == today;
      case EventDateRange.week:
        final end = today.add(const Duration(days: 7));
        return !eventDay.isBefore(today) && eventDay.isBefore(end);
      case EventDateRange.month:
        return event.date.year == now.year && event.date.month == now.month;
    }
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
          return !event.date.isBefore(now);
        }).toList();
      case EventFilterType.enVivo:
        events = allEvents.where((e) => e.isLive).toList();
      case EventFilterType.proximos:
        events = allEvents.where((e) => e.isFuture).toList();
      case EventFilterType.todos:
        events = List<EventData>.from(allEvents);
    }

    if (eventScope == EventScope.iglesia && selectedDenomination != null) {
      events = events.where((e) => _matchesDenominationFilter(e, selectedDenomination!)).toList();
    }

    if (selectedChristianCategories.isNotEmpty) {
      events = events.where((e) {
        return selectedChristianCategories.any((name) => _matchesDenominationFilter(e, name));
      }).toList();
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
          return cat.contains(t);
        });
      }).toList();
    }

    events = events.where(_inDateRange).toList();
    return filterBySearch(events);
  }

  Future<void> handleDenominationSelect(String denomination) async {
    final userId = AuthService().currentUser?.id;
    await _prefs.setDenomination(userId, denomination);
    selectedDenomination = denomination;
    showInitialSelector = false;
    notifyListeners();
    await refreshEvents();
  }

  void setActiveFilter(EventFilterType filter) {
    activeFilter = filter;
    notifyListeners();
  }

  void setEventScope(EventScope scope) {
    eventScope = scope;
    notifyListeners();
    refreshEvents();
  }

  void setDateRange(EventDateRange range) {
    dateRange = dateRange == range ? EventDateRange.any : range;
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

  void openDenominationChangeForm() {
    showDenominationDropdown = false;
    showDenominationChangeForm = true;
    notifyListeners();
  }

  void closeDenominationChangeForm() {
    showDenominationChangeForm = false;
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
        message: 'Tu solicitud fue enviada al administrador de KAIRO. Te avisaremos cuando sea revisada.',
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
      hasPendingEventRequest = false;
      eventRequestForm = EventRequestFormData.empty;
      showEventRequestForm = false;
      _showPendingNotice(
        title: 'Evento publicado',
        message: 'Tu evento ya está visible en el catálogo de KAIRO.',
      );
      await refreshEvents();
    } catch (e) {
      eventSubmitError = _eventsRepository.mapError(e);
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
}
